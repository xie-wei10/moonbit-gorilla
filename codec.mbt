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
  for i = width - 1; i >= 0; i = i - 1 {
    self.partial = (self.partial << 1) | ((n >> i) & 1UL).to_int()
    self.used += 1
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
  for _ in 0..<n {
    out = (out << 1) |
      ((self.bytes[self.pos / 8].to_uint64() >> (7 - self.pos % 8)) & 1UL)
    self.pos += 1
  }
  out
}

///|
fn zeros(x : UInt64) -> (Int, Int) {
  let mut lead = 0
  let mut trail = 0
  while lead < 64 && ((x >> (63 - lead)) & 1UL) == 0UL {
    lead += 1
  }
  while trail < 64 && ((x >> trail) & 1UL) == 0UL {
    trail += 1
  }
  (lead, trail)
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
