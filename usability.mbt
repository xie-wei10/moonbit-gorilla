///|
/// Decode and filter a closed timestamp range. This is a full sequential decode.
pub fn decode_range(
  data : Bytes,
  start : Int64,
  end : Int64,
) -> Array[Sample] raise CodecError {
  if start < 0L || end < start {
    raise Invalid("invalid time range")
  }
  let decoder = Decoder::new(data)
  let out = []
  while decoder.next() is Some(sample) {
    if sample.timestamp >= start && sample.timestamp <= end {
      out.push(sample)
    }
  }
  out
}
