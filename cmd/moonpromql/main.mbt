///|
fn labels_json(labels : @model.LabelSet) -> Json {
  Json::array(
    labels.labels.map(pair => Json::array([pair.0.to_json(), pair.1.to_json()])),
  )
}

///|
fn value_json(value : @model.Value) -> Json {
  match value {
    Scalar(v) => { "kind": "scalar", "value": v.to_string() }
    StringValue(v) => { "kind": "string", "value": v }
    Instant(points) =>
      {
        "kind": "instant",
        "points": points.map(p => {
          (
            { "labels": labels_json(p.labels), "value": p.value.to_string() } :
            Json)
        }),
      }
    Range(items) =>
      {
        "kind": "range",
        "series": items.map(s => {
          (
            {
              "labels": labels_json(s.labels),
              "samples": s.samples.map(p => {
                (
                  {
                    "timestamp": p.timestamp.to_string(),
                    "value": p.value.to_string(),
                  } : Json)
              }),
            } : Json)
        }),
      }
  }
}

///|
pub fn query_json(input : String) -> String {
  try {
    if input.length() > 16000000 {
      raise Failure("request byte/character limit")
    }
    let request = @json.parse(input)
    let (action, query, at) = match request {
      { "action": String(a), "query": String(q), "at": String(t), .. } =>
        (a, q, @strconv.parse_int64(t))
      _ => raise Failure("expected action, query, at string")
    }
    let plan = @adapter.plan(query, at)
    let window = match plan.read_window() {
      None => Json::null()
      Some((start, end)) =>
        ({ "start": start.to_string(), "end": end.to_string() } : Json)
    }
    let result = if action == "plan" {
      window
    } else if action == "evaluate" {
      let raw = match request {
        { "series": Array(items), .. } => items
        _ => raise Failure("expected series")
      }
      if raw.length() > 64 {
        raise Failure("series count limit")
      }
      let mut total = 0
      let series = raw.map(item => {
        match item {
          {
            "metric": String(metric),
            "labels": Array(labels),
            "samples": Array(samples),
            ..
          } => {
            total += samples.length()
            if total > 100000 {
              raise Failure("aggregate sample limit")
            }
            let labels = labels.map(pair => {
              match pair {
                Array([String(k), String(v)]) => (k, v)
                _ => raise Failure("labels must be pairs")
              }
            })
            let samples = samples.map(sample => {
              match sample {
                { "timestamp": String(t), "bits": String(b), .. } =>
                  @archive.Sample::{
                    timestamp: @strconv.parse_int64(t),
                    bits: @strconv.parse_uint64(b),
                  }
                _ =>
                  raise Failure(
                    "samples require decimal timestamp/bits strings",
                  )
              }
            })
            @adapter.series(metric, labels, samples)
          }
          _ => raise Failure("invalid series")
        }
      })
      value_json(plan.evaluate(series))
    } else {
      raise Failure("unknown action")
    }
    ({ "ok": true, "result": result } : Json).stringify()
  } catch {
    error =>
      ({ "ok": false, "error": Repr(error).to_string() } : Json).stringify()
  }
}

///|
fn main {
  ()
}
