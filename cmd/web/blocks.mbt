///|
fn to_hex(data : Bytes) -> String {
  let digits = "0123456789abcdef".to_array()
  let out = StringBuilder()
  for b in data {
    out.write_char(digits[b.to_int() / 16])
    out.write_char(digits[b.to_int() % 16])
  }
  out.to_string()
}

///|
fn from_hex(hex : String) -> Bytes raise Failure {
  if hex.length() > 4000000 || hex.length() % 2 != 0 {
    raise Failure("invalid encoded length")
  }
  let out = []
  let mut byte = 0
  for i, c in hex.to_array() {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'a' && c <= 'f' {
      c.to_int() - 87
    } else {
      -1
    }
    if digit < 0 {
      raise Failure("lowercase hex required")
    }
    byte = byte * 16 + digit
    if i % 2 == 1 {
      out.push(byte.to_byte())
      byte = 0
    }
  }
  Bytes::from_array(out)
}

///|
pub fn compress_text(source : String) -> String {
  try {
    if source.length() > 5000000 {
      raise Failure("input text limit")
    }
    let encoder = @lib.Encoder::new()
    for line in source.split("\n") {
      if line.trim().is_empty() {
        continue
      }
      let parts = line
        .trim()
        .to_owned()
        .replace_all(old="\t", new=" ")
        .split(" ")
        .filter(s => !s.is_empty())
        .collect()
      if parts.length() != 2 {
        raise Failure("expected timestamp raw_uint64_bits")
      }
      encoder.append({
        timestamp: @strconv.parse_int64(parts[0].to_owned()),
        bits: @strconv.parse_uint64(parts[1].to_owned()),
      })
    }
    to_hex(encoder.finish())
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}

///|
pub fn decompress_text(hex : String, start : String, end : String) -> String {
  try {
    let low = @strconv.parse_int64(start)
    let high = @strconv.parse_int64(end)
    if low < 0L || high < low || high > 9007199254740991L {
      raise Failure("invalid range")
    }
    let decoder = @lib.Decoder::new(from_hex(hex))
    let out = StringBuilder()
    while decoder.next() is Some(sample) {
      if sample.timestamp >= low && sample.timestamp <= high {
        out.write_string(
          sample.timestamp.to_string() + " " + sample.bits.to_string() + "\n",
        )
      }
    }
    out.to_string()
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}
