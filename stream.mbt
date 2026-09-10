///|
/// Appends directly to packed bytes; does not retain a Sample array or one Int per bit.
pub struct Encoder {
  priv writer : Writer
  priv mut count : Int
  priv mut previous : UInt64
  priv mut time : Int64
  priv mut delta : Int64
  priv mut leading : Int
  priv mut trailing : Int
  priv mut closed : Bool
}

///|
pub fn Encoder::new() -> Encoder {
  let writer = Writer::{ bytes: [], partial: 0, used: 0, }
  writer.put(0x474f5231UL, 32)
  writer.put(0UL, 32)
  {
    writer,
    count: 0,
    previous: 0UL,
    time: 0L,
    delta: 0L,
    leading: 64,
    trailing: 0,
    closed: false,
  }
}

///|
/// Rejected samples leave the encoder unchanged; finish seals further appends.
pub fn Encoder::append(
  self : Encoder,
  sample : Sample,
) -> Unit raise CodecError {
  if self.closed {
    raise Invalid("encoder finished")
  }
  if self.count == 100000 {
    raise Invalid("sample limit")
  }
  if sample.timestamp < 0L || sample.timestamp > 9007199254740991L {
    raise Invalid("timestamp outside safe range")
  }
  if self.count > 0 && sample.timestamp < self.time {
    raise Invalid("timestamps must be nondecreasing")
  }
  let w = self.writer
  if self.count == 0 {
    w.put(sample.timestamp.reinterpret_as_uint64(), 64)
    w.put(sample.bits, 64)
  } else {
    let d = sample.timestamp - self.time
    let dd = d - self.delta
    if dd == 0L {
      w.put(0UL, 1)
    } else if dd >= -63L && dd <= 64L {
      w.put(2UL, 2)
      w.put((dd + 63L).reinterpret_as_uint64(), 7)
    } else if dd >= -255L && dd <= 256L {
      w.put(6UL, 3)
      w.put((dd + 255L).reinterpret_as_uint64(), 9)
    } else if dd >= -2047L && dd <= 2048L {
      w.put(14UL, 4)
      w.put((dd + 2047L).reinterpret_as_uint64(), 12)
    } else {
      w.put(15UL, 4)
      w.put(dd.reinterpret_as_uint64(), 64)
    }
    let xor = self.previous ^ sample.bits
    if xor == 0UL {
      w.put(0UL, 1)
    } else {
      w.put(1UL, 1)
      let (leading, trailing) = zeros(xor)
      if leading >= self.leading && trailing >= self.trailing {
        w.put(0UL, 1)
        w.put(xor >> self.trailing, 64 - self.leading - self.trailing)
      } else {
        self.leading = leading
        self.trailing = trailing
        w.put(1UL, 1)
        w.put(leading.to_uint64(), 6)
        w.put((64 - leading - trailing).to_uint64() & 63UL, 6)
        w.put(xor >> trailing, 64 - leading - trailing)
      }
    }
    self.delta = d
  }
  self.time = sample.timestamp
  self.previous = sample.bits
  self.count += 1
}

///|
/// Independent, padded GOR1 snapshot. Continuing to append cannot mutate a prior snapshot.
pub fn Encoder::snapshot(self : Encoder) -> Bytes {
  self.writer.snapshot(self.count)
}

///|
pub fn Encoder::finish(self : Encoder) -> Bytes {
  self.closed = true
  self.snapshot()
}

///|
pub fn Encoder::length(self : Encoder) -> Int {
  self.count
}

///|
pub fn Encoder::encoded_size(self : Encoder) -> Int {
  self.writer.bytes.length() + (if self.writer.used > 0 { 1 } else { 0 })
}

///|
/// Iterates over a complete GOR1 byte block using constant decoder state.
/// This is a sample iterator, not a transport that accepts partial byte chunks.
pub struct Decoder {
  priv reader : Reader
  priv count : Int
  priv mut index : Int
  priv mut time : Int64
  priv mut delta : Int64
  priv mut previous : UInt64
  priv mut leading : Int
  priv mut trailing : Int
  priv mut failed : Bool
  priv mut verified : Bool
}

///|
pub fn Decoder::new(data : Bytes) -> Decoder raise CodecError {
  if data.length() > 2000000 {
    raise Invalid("encoded block limit")
  }
  let reader = Reader::{ bytes: data, pos: 0, }
  if reader.get(32) != 0x474f5231UL {
    raise Invalid("not GOR1")
  }
  let count = reader.get(32)
  if count > 100000UL {
    raise Invalid("sample limit")
  }
  {
    reader,
    count: count.to_int(),
    index: 0,
    time: 0L,
    delta: 0L,
    previous: 0UL,
    leading: 64,
    trailing: 0,
    failed: false,
    verified: false,
  }
}

///|
fn Decoder::verify_tail(self : Decoder) -> Unit raise CodecError {
  let r = self.reader
  if r.bytes.length() * 8 - r.pos >= 8 {
    raise Invalid("trailing bytes")
  }
  while r.pos < r.bytes.length() * 8 {
    if r.get(1) != 0UL {
      raise Invalid("nonzero padding")
    }
  }
  self.verified = true
}

///|
fn Decoder::read_sample(self : Decoder) -> Sample? raise CodecError {
  if self.index == self.count {
    if !self.verified {
      self.verify_tail()
    }
    return None
  }
  let r = self.reader
  if self.index == 0 {
    self.time = r.get(64).reinterpret_as_int64()
    self.previous = r.get(64)
  } else {
    let dd = if r.get(1) == 0UL {
      0L
    } else if r.get(1) == 0UL {
      r.get(7).reinterpret_as_int64() - 63L
    } else if r.get(1) == 0UL {
      r.get(9).reinterpret_as_int64() - 255L
    } else if r.get(1) == 0UL {
      r.get(12).reinterpret_as_int64() - 2047L
    } else {
      r.get(64).reinterpret_as_int64()
    }
    if dd < -9007199254740991L || dd > 9007199254740991L {
      raise Invalid("delta range")
    }
    self.delta += dd
    if self.delta < 0L || self.delta > 9007199254740991L - self.time {
      raise Invalid("timestamp overflow/order")
    }
    self.time += self.delta
    if r.get(1) != 0UL {
      if r.get(1) != 0UL {
        self.leading = r.get(6).to_int()
        let size = r.get(6).to_int()
        let size = if size == 0 { 64 } else { size }
        self.trailing = 64 - self.leading - size
        if self.trailing < 0 {
          raise Invalid("invalid XOR window")
        }
      } else if self.leading == 64 {
        raise Invalid("missing XOR window")
      }
      self.previous = self.previous ^
        (r.get(64 - self.leading - self.trailing) << self.trailing)
    }
  }
  if self.time < 0L || self.time > 9007199254740991L {
    raise Invalid("timestamp range")
  }
  self.index += 1
  // Validate the tail before exposing the final sample, so truncation/padding is never reported as EOF.
  if self.index == self.count {
    self.verify_tail()
  }
  Some({ timestamp: self.time, bits: self.previous, })
}

///|
pub fn Decoder::next(self : Decoder) -> Sample? raise CodecError {
  if self.failed {
    raise Invalid("decoder is in failed state")
  }
  errdefer {
    self.failed = true
  }
  self.read_sample()
}

///|
/// Drain remaining samples without retaining them; validates all remaining bytes.
pub fn Decoder::finish(self : Decoder) -> Unit raise CodecError {
  while self.next() is Some(_) {

  }
}

///|
pub fn Decoder::remaining(self : Decoder) -> Int {
  self.count - self.index
}

///|
pub fn Decoder::is_verified(self : Decoder) -> Bool {
  self.verified && !self.failed
}
