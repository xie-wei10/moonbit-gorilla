///|
pub fn run(input : String) -> String {
  try {
    let samples : Array[@lib.Sample] = []
    for line in input.split("\n") {
      if line.trim().is_empty() {
        continue
      }
      let p = line.trim().split(" ").filter(s => !s.is_empty()).collect()
      if p.length() != 2 {
        return "ERROR: timestamp raw_uint64_bits"
      }
      samples.push({
        timestamp: @strconv.parse_int64(p[0].to_owned()),
        bits: @strconv.parse_uint64(p[1].to_owned()),
      })
    }
    let data = @lib.encode(samples)
    let restored = @lib.decode(data)
    "Samples: " +
    samples.length().to_string() +
    "\nEncoded bytes: " +
    data.length().to_string() +
    "\nRaw sample bytes: " +
    (samples.length() * 16).to_string() +
    "\nDecoded: " +
    Repr(restored).to_string()
  } catch {
    e => "ERROR: " + Repr(e).to_string()
  }
}

///|
fn main {

}
