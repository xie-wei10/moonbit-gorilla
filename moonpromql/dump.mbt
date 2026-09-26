///|
/// Finite numeric promtool tsdb dump series. Timestamps are exact milliseconds.
pub(all) struct DumpSeries {
  metric : String
  labels : Array[(String, String)]
  samples : Array[@archive.Sample]
}

///|
/// Bounded text ingress, not OpenMetrics exposition or native TSDB blocks.
/// Equality labels are parsed by the existing MoonPromQL parser. No histogram,
/// stale/NaN, regex selector, implicit timestamp, or duplicate sample is dropped.
pub fn parse_promtool_dump(source : String) -> Array[DumpSeries] raise {
  if source.length() > 4000000 {
    raise Invalid("dump exceeds 4M UTF-16 units")
  }
  let output : Array[DumpSeries] = []
  let identities : Map[String, Int] = Map([])
  let mut total = 0
  let mut line_number = 0
  for raw in source.split("\n") {
    line_number += 1
    let line = raw.trim().to_owned()
    if line.is_empty() {
      continue
    }
    try {
      if line.length() > 16384 || !line.has_prefix("{") {
        raise Invalid("expected bounded braced labels")
      }
      let mut quoted = false
      let mut escaped = false
      let mut end = -1
      for i in 1..<line.length() {
        let c = line[i]
        if escaped {
          escaped = false
        } else if quoted && c == 92 {
          escaped = true
        } else if c == 34 {
          quoted = !quoted
        } else if !quoted && c == 125 {
          end = i
          break
        }
      }
      if end < 0 ||
        end + 1 >= line.length() ||
        (line[end + 1] != 32 && line[end + 1] != 9) {
        raise Invalid("expected labels then value and timestamp")
      }
      let selector = match @parser.parse(line[:end + 1]) {
        Selector(s) => s
        _ => raise Invalid("expected literal labels")
      }
      let seen : Map[String, Bool] = Map([])
      let mut metric = ""
      let labels : Array[(String, String)] = []
      for matcher in selector.matchers {
        match matcher.op {
          Equal => ()
          _ => raise Invalid("dump labels must use equality")
        }
        if seen.contains(matcher.name) {
          raise Invalid("duplicate dump label")
        }
        seen[matcher.name] = true
        if matcher.name == "__name__" {
          metric = matcher.value
        } else {
          labels.push((matcher.name, matcher.value))
        }
      }
      labels.sort_by((a, b) => a.0.compare(b.0))
      // Reuse the query adapter's exact metadata contract without rechecking an
      // ever-growing series on every line (which would be quadratic).
      ignore(series(metric, labels, []))
      let fields = line[end + 1:]
        .to_owned()
        .replace_all(old="\t", new=" ")
        .split(" ")
        .filter(s => !s.is_empty())
        .collect()
      if fields.length() != 2 {
        raise Invalid("expected numeric value and integer ms timestamp")
      }
      if !fields[0]
        .to_owned()
        .iter()
        .all(c => "0123456789.eE+-".contains(c.to_string())) {
        raise Invalid("only finite decimal samples supported")
      }
      let value = @strconv.parse_double(fields[0].to_owned())
      let bits = value.reinterpret_as_int64().reinterpret_as_uint64()
      if (bits & 0x7ff0000000000000UL) == 0x7ff0000000000000UL {
        raise Invalid("nonfinite sample")
      }
      let time_text = fields[1].to_owned()
      if time_text.is_empty() ||
        !time_text.iter().all(c => "0123456789-".contains(c.to_string())) {
        raise Invalid("timestamp must be decimal integer milliseconds")
      }
      let timestamp = @strconv.parse_int64(time_text)
      if timestamp < -9007199254740991L || timestamp > 9007199254740991L {
        raise Invalid("timestamp loses precision")
      }
      total += 1
      if total > 100000 {
        raise Invalid("dump aggregate sample limit")
      }
      let identity = Json::array([
        metric.to_json(),
        Json::array(
          labels.map(p => Json::array([p.0.to_json(), p.1.to_json()])),
        ),
      ]).stringify()
      let index = match identities.get(identity) {
        Some(index) => index
        None => {
          if output.length() >= 64 {
            raise Invalid("dump series limit")
          }
          let index = output.length()
          identities[identity] = index
          output.push({ metric, labels, samples: [], })
          index
        }
      }
      let samples = output[index].samples
      if !samples.is_empty() &&
        samples[samples.length() - 1].timestamp >= timestamp {
        raise Invalid("duplicate or out-of-order series timestamp")
      }
      samples.push({ timestamp, bits, })
    } catch {
      error =>
        raise Invalid("dump line \{line_number}: " + Repr(error).to_string())
    }
  }
  output
}
