///|
fn sample_json(sample : @lib.Sample) -> Json {
  {
    "timestamp": sample.timestamp.to_string().to_json(),
    "bits": sample.bits.to_string().to_json(),
  }
}

///|
fn read_samples(value : Json) -> Array[@lib.Sample] raise {
  match value {
    Array(items) => {
      if items.length() > 100000 {
        raise Failure("sample limit")
      }
      items.map(item => {
        match item {
          { "timestamp": String(time), "bits": String(bits), .. } =>
            @lib.Sample::{
              timestamp: @strconv.parse_int64(time),
              bits: @strconv.parse_uint64(bits),
            }
          _ => raise Failure("timestamp and bits must be decimal strings")
        }
      })
    }
    _ => raise Failure("expected samples array")
  }
}

///|
extern "js" fn monotonic_ms() -> Double = "() => performance.now()"

///|
pub fn codec_json(input : String) -> String {
  try {
    if input.length() > 16000000 {
      raise Failure("request limit")
    }
    let request = @json.parse(input)
    let result = match request {
      { "operation": String("benchmark"), "samples": samples, .. } => {
        let samples = read_samples(samples)
        let repeats = archive_integer(request, "repeats", default=5)
        if repeats < 1 || repeats > 100 {
          raise Failure("repeat limit")
        }
        let mut bytes = b""
        let mut decoded : Array[@lib.Sample] = []
        let start = monotonic_ms()
        for _ in 0..<repeats {
          bytes = @lib.encode_xor(samples)
        }
        let encoded = monotonic_ms()
        for _ in 0..<repeats {
          decoded = @lib.decode_xor(bytes)
        }
        let finished = monotonic_ms()
        if decoded != samples {
          raise Failure("benchmark roundtrip mismatch")
        }
        Json::object({
          "hex": to_hex(bytes).to_json(),
          "encodeMs": ((encoded - start) / repeats.to_double()).to_json(),
          "decodeMs": ((finished - encoded) / repeats.to_double()).to_json(),
          "samples": samples.length().to_json(),
        })
      }
      {
        "operation": String("encode"),
        "format": String(format),
        "samples": samples,
        ..
      } => {
        let samples = read_samples(samples)
        let bytes = match format {
          "xor" => @lib.encode_xor(samples)
          "gor1" => @lib.encode(samples)
          _ => raise Failure("unknown format")
        }
        Json::object({ "hex": to_hex(bytes).to_json() })
      }
      {
        "operation": String("decode"),
        "format": String(format),
        "hex": String(hex),
        ..
      } => {
        let bytes = from_hex(hex)
        let strict = match request {
          { "strict": False, .. } => false
          _ => true
        }
        let samples = match format {
          "xor" => @lib.decode_xor(bytes, strict~)
          "gor1" => @lib.decode(bytes)
          _ => raise Failure("unknown format")
        }
        Json::object({ "samples": Json::array(samples.map(sample_json)) })
      }
      _ => raise Failure("unknown codec request")
    }
    Json::object({ "ok": true, "result": result }).stringify()
  } catch {
    e =>
      Json::object({ "ok": false, "error": Repr(e).to_string().to_json() }).stringify()
  }
}
