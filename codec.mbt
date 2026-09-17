///|
pub suberror CodecError {
  Invalid(String)
} derive(Debug)

///|
pub(all) struct Sample {
  timestamp : Int64
  bits : UInt64
} derive(Debug, Eq)

///|
priv struct Writer {
  bytes : Array[Byte]
  mut partial : Int
  mut used : Int
}

///|
fn Writer::put(self : Writer, n : UInt64, width : Int) -> Unit {
  let mut remaining = width
  while remaining > 0 {
    let take = Int::min(remaining, 8 - self.used)
    let bits = ((n >> (remaining - take)) & ((1UL << take) - 1UL)).to_int()
    self.partial = (self.partial << take) | bits
    self.used += take
    remaining -= take
    if self.used == 8 {
      self.bytes.push(self.partial.to_byte())
      self.partial = 0
      self.used = 0
    }
  }
}

///|
fn Writer::snapshot(self : Writer, count : Int) -> Bytes {
  let data = self.bytes.copy()
  if self.used > 0 {
    data.push((self.partial << (8 - self.used)).to_byte())
  }
  for i in 0..<4 {
    data[4 + i] = ((count >> ((3 - i) * 8)) & 255).to_byte()
  }
  Bytes::from_array(data)
}

///|
priv struct Reader {
  bytes : Bytes
  mut pos : Int
}

///|
fn Reader::get(self : Reader, n : Int) -> UInt64 raise CodecError {
  if n < 0 || self.pos + n > self.bytes.length() * 8 {
    raise Invalid("truncated bitstream")
  }
  let mut out = 0UL
  let mut remaining = n
  while remaining > 0 {
    let available = 8 - self.pos % 8
    let take = Int::min(remaining, available)
    let bits = (self.bytes[self.pos / 8].to_int() >> (available - take)) &
      ((1 << take) - 1)
    out = (out << take) | bits.to_uint64()
    self.pos += take
    remaining -= take
  }
  out
}

///|
fn zeros(x : UInt64) -> (Int, Int) {
  (x.clz(), x.ctz())
}

///|
pub fn encode(samples : Array[Sample]) -> Bytes raise CodecError {
  if samples.length() > 100000 {
    raise Invalid("sample limit")
  }
  let encoder = Encoder::new()
  for sample in samples {
    encoder.append(sample)
  }
  encoder.finish()
}

///|
pub fn decode(data : Bytes) -> Array[Sample] raise CodecError {
  let decoder = Decoder::new(data)
  let out = []
  while decoder.next() is Some(sample) {
    out.push(sample)
  }
  out
}
