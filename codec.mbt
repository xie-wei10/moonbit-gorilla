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
  bits : Array[Int]
}

///|
fn Writer::put(self : Writer, n : UInt64, width : Int) -> Unit {
  for i = width - 1; i >= 0; i = i - 1 {
    self.bits.push(((n >> i) & 1UL).to_int())
  }
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
  let w = Writer::{ bits: [], }
  w.put(0x474f5231UL, 32)
  w.put(samples.length().to_uint64(), 32)
  let mut previous = 0UL
  let mut time = 0L
  let mut delta = 0L
  let mut leading = 64
  let mut trailing = 0
  for i, s in samples {
    if s.timestamp < 0L || s.timestamp > 9007199254740991L {
      raise Invalid("timestamp outside safe range")
    }
    if i == 0 {
      w.put(s.timestamp.reinterpret_as_uint64(), 64)
      w.put(s.bits, 64)
    } else {
      let d = s.timestamp - time
      if d < 0L {
        raise Invalid("timestamps must be nondecreasing")
      }
      let dd = d - delta
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
      let x = previous ^ s.bits
      if x == 0UL {
        w.put(0UL, 1)
      } else {
        w.put(1UL, 1)
        let (l, t) = zeros(x)
        if l >= leading && t >= trailing {
          w.put(0UL, 1)
          w.put(x >> trailing, 64 - leading - trailing)
        } else {
          leading = l
          trailing = t
          w.put(1UL, 1)
          w.put(l.to_uint64(), 6)
          w.put((64 - l - t).to_uint64() & 63UL, 6)
          w.put(x >> t, 64 - l - t)
        }
      }
      delta = d
    }
    time = s.timestamp
    previous = s.bits
  }
  let data : Array[Byte] = []
  for i = 0; i < w.bits.length(); i = i + 8 {
    let mut b = 0
    for j in 0..<8 {
      b = b << 1
      if i + j < w.bits.length() {
        b = b | w.bits[i + j]
      }
    }
    data.push(b.to_byte())
  }
  Bytes::from_array(data)
}

///|
pub fn decode(data : Bytes) -> Array[Sample] raise CodecError {
  let r = Reader::{ bytes: data, pos: 0, }
  if r.get(32) != 0x474f5231UL {
    raise Invalid("not GOR1")
  }
  let n = r.get(32)
  if n > 100000UL {
    raise Invalid("sample limit")
  }
  let result : Array[Sample] = []
  let mut time = 0L
  let mut delta = 0L
  let mut previous = 0UL
  let mut leading = 64
  let mut trailing = 0
  for i in 0..<n.to_int() {
    if i == 0 {
      time = r.get(64).reinterpret_as_int64()
      previous = r.get(64)
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
      delta += dd
      if delta < 0L || delta > 9007199254740991L - time {
        raise Invalid("timestamp overflow/order")
      }
      time += delta
      if r.get(1) != 0UL {
        if r.get(1) != 0UL {
          leading = r.get(6).to_int()
          let size = r.get(6).to_int()
          let size = if size == 0 { 64 } else { size }
          trailing = 64 - leading - size
          if trailing < 0 {
            raise Invalid("invalid XOR window")
          }
        } else if leading == 64 {
          raise Invalid("missing XOR window")
        }
        previous = previous ^ (r.get(64 - leading - trailing) << trailing)
      }
    }
    if time < 0L || time > 9007199254740991L {
      raise Invalid("timestamp range")
    }
    result.push({ timestamp: time, bits: previous, })
  }
  if data.length() * 8 - r.pos >= 8 {
    raise Invalid("trailing bytes")
  }
  while r.pos < data.length() * 8 {
    if r.get(1) != 0UL {
      raise Invalid("nonzero padding")
    }
  }
  result
}
