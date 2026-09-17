///|
/// Prometheus XOR chunk, with its two-byte sample count and no segment wrapper.
pub struct XorEncoder {
  priv writer : Writer
  priv mut count : Int
  priv mut time : Int64
  priv mut delta : UInt64
  priv mut bits : UInt64
  priv mut leading : Int
  priv mut trailing : Int
  priv mut closed : Bool
}

///|
pub fn XorEncoder::new() -> XorEncoder {
  {
    writer: { bytes: [0, 0], partial: 0, used: 0, },
    count: 0,
    time: 0L,
    delta: 0UL,
    bits: 0UL,
    leading: 64,
    trailing: 0,
    closed: false,
  }
}

///|
fn Writer::varuint(self : Writer, n : UInt64) -> Unit {
  let mut n = n
  while n >= 128UL {
    self.put((n & 127UL) | 128UL, 8)
    n = n >> 7
  }
  self.put(n, 8)
}

///|
fn Reader::varuint(self : Reader) -> UInt64 raise CodecError {
  let mut n = 0UL
  for i in 0..<10 {
    let b = self.get(8)
    if i == 9 && b > 1UL {
      raise Invalid("varint overflow")
    }
    n = n | ((b & 127UL) << (i * 7))
    if b < 128UL {
      return n
    }
  }
  raise Invalid("unterminated varint")
}

///|
/// Uses signed 64-bit timestamps and bit-exact values; ordering is not imposed.
/// Like the reference chunk codec, delta arithmetic wraps modulo 2^64.
pub fn XorEncoder::append(
  self : XorEncoder,
  sample : Sample,
) -> Unit raise CodecError {
  if self.closed {
    raise Invalid("encoder finished")
  }
  if self.count >= 65535 {
    raise Invalid("XOR chunk sample limit")
  }
  let writer = self.writer
  let time_bits = sample.timestamp.reinterpret_as_uint64()
  let delta = time_bits - self.time.reinterpret_as_uint64()
  if self.count == 0 {
    writer.varuint(
      (time_bits << 1) ^ (sample.timestamp >> 63).reinterpret_as_uint64(),
    )
    writer.put(sample.bits, 64)
  } else {
    if self.count == 1 {
      writer.varuint(delta)
    } else {
      let difference = (delta - self.delta).reinterpret_as_int64()
      if difference == 0L {
        writer.put(0UL, 1)
      } else {
        let width = if difference >= -8191L && difference <= 8192L {
          14
        } else if difference >= -65535L && difference <= 65536L {
          17
        } else if difference >= -524287L && difference <= 524288L {
          20
        } else {
          64
        }
        if width == 14 {
          writer.put(2UL, 2)
        } else if width == 17 {
          writer.put(6UL, 3)
        } else if width == 20 {
          writer.put(14UL, 4)
        } else {
          writer.put(15UL, 4)
        }
        writer.put(difference.reinterpret_as_uint64(), width)
      }
    }
    let changed = self.bits ^ sample.bits
    if changed == 0UL {
      writer.put(0UL, 1)
    } else {
      writer.put(1UL, 1)
      let (lz, tz) = zeros(changed)
      let lz = if lz > 31 { 31 } else { lz }
      if self.leading != 64 && lz >= self.leading && tz >= self.trailing {
        writer.put(0UL, 1)
        writer.put(changed >> self.trailing, 64 - self.leading - self.trailing)
      } else {
        writer.put(1UL, 1)
        writer.put(lz.to_uint64(), 5)
        writer.put((64 - lz - tz).to_uint64() & 63UL, 6)
        writer.put(changed >> tz, 64 - lz - tz)
        self.leading = lz
        self.trailing = tz
      }
    }
  }
  self.delta = delta
  self.time = sample.timestamp
  self.bits = sample.bits
  self.count += 1
}

///|
pub fn XorEncoder::snapshot(self : XorEncoder) -> Bytes {
  let bytes = self.writer.bytes.copy()
  if self.writer.used > 0 {
    bytes.push((self.writer.partial << (8 - self.writer.used)).to_byte())
  }
  bytes[0] = (self.count >> 8).to_byte()
  bytes[1] = (self.count & 255).to_byte()
  Bytes::from_array(bytes)
}

///|
pub fn XorEncoder::finish(self : XorEncoder) -> Bytes {
  self.closed = true
  self.snapshot()
}

///|
pub fn XorEncoder::length(self : XorEncoder) -> Int {
  self.count
}

///|
pub fn XorEncoder::encoded_size(self : XorEncoder) -> Int {
  self.writer.bytes.length() + (if self.writer.used == 0 { 0 } else { 1 })
}

///|
pub fn encode_xor(samples : Array[Sample]) -> Bytes raise CodecError {
  if samples.length() > 65535 {
    raise Invalid("XOR chunk sample limit")
  }
  let encoder = XorEncoder::new()
  for sample in samples {
    encoder.append(sample)
  }
  encoder.finish()
}

///|
pub struct XorDecoder {
  priv reader : Reader
  priv count : Int
  priv strict : Bool
  priv mut index : Int
  priv mut time : Int64
  priv mut delta : UInt64
  priv mut bits : UInt64
  priv mut leading : Int
  priv mut trailing : Int
  priv mut failed : Bool
  priv mut verified : Bool
}

///|
/// strict=true rejects nonzero padding/trailing bytes. The reference iterator
/// stops at the sample count; strict=false retains that framing behavior.
pub fn XorDecoder::new(
  data : Bytes,
  strict? : Bool = true,
) -> XorDecoder raise CodecError {
  if data.length() < 2 || data.length() > 2000000 {
    raise Invalid("XOR chunk byte limit")
  }
  {
    reader: { bytes: data, pos: 16, },
    count: (data[0].to_int() << 8) | data[1].to_int(),
    strict,
    index: 0,
    time: 0L,
    delta: 0UL,
    bits: 0UL,
    leading: 0,
    trailing: 0,
    failed: false,
    verified: false,
  }
}

///|
fn XorDecoder::verify_tail(self : XorDecoder) -> Unit raise CodecError {
  if self.strict {
    if self.reader.bytes.length() * 8 - self.reader.pos >= 8 {
      raise Invalid("trailing XOR chunk bytes")
    }
    while self.reader.pos < self.reader.bytes.length() * 8 {
      if self.reader.get(1) != 0UL {
        raise Invalid("nonzero XOR padding")
      }
    }
  }
  self.verified = true
}

///|
pub fn XorDecoder::next(self : XorDecoder) -> Sample? raise CodecError {
  if self.failed {
    raise Invalid("decoder is in failed state")
  }
  errdefer {
    self.failed = true
  }
  if self.index == self.count {
    if !self.verified {
      self.verify_tail()
    }
    return None
  }
  let reader = self.reader
  if self.index == 0 {
    let n = reader.varuint()
    self.time = ((n >> 1) ^ (0UL - (n & 1UL))).reinterpret_as_int64()
    self.bits = reader.get(64)
  } else {
    if self.index == 1 {
      self.delta = reader.varuint()
    } else {
      let mut ones = 0
      while ones < 4 {
        if reader.get(1) == 0UL {
          break
        }
        ones += 1
      }
      let width = match ones {
        0 => 0
        1 => 14
        2 => 17
        3 => 20
        _ => 64
      }
      if width > 0 {
        let n = reader.get(width)
        let difference = if width < 64 && n > 1UL << (width - 1) {
          n - (1UL << width)
        } else {
          n
        }
        self.delta += difference
      }
    }
    self.time = (self.time.reinterpret_as_uint64() + self.delta).reinterpret_as_int64()
    if reader.get(1) == 1UL {
      if reader.get(1) == 1UL {
        self.leading = reader.get(5).to_int()
        let width = reader.get(6).to_int()
        let width = if width == 0 { 64 } else { width }
        if self.leading + width > 64 {
          raise Invalid("invalid XOR window")
        }
        self.trailing = 64 - self.leading - width
      }
      self.bits = self.bits ^
        (reader.get(64 - self.leading - self.trailing) << self.trailing)
    }
  }
  self.index += 1
  if self.index == self.count {
    self.verify_tail()
  }
  Some({ timestamp: self.time, bits: self.bits, })
}

///|
pub fn XorDecoder::finish(self : XorDecoder) -> Unit raise CodecError {
  while self.next() is Some(_) {

  }
}

///|
pub fn XorDecoder::remaining(self : XorDecoder) -> Int {
  self.count - self.index
}

///|
pub fn XorDecoder::is_verified(self : XorDecoder) -> Bool {
  self.verified && !self.failed
}

///|
pub fn decode_xor(
  data : Bytes,
  strict? : Bool = true,
) -> Array[Sample] raise CodecError {
  let decoder = XorDecoder::new(data, strict~)
  let samples = []
  while decoder.next() is Some(sample) {
    samples.push(sample)
  }
  samples
}
