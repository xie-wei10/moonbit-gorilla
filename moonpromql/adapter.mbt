///|
pub(all) suberror AdapterError {
  Invalid(String)
} derive(Debug)

///|
/// Parsed by the pinned upstream parser. The expression stays private so the
/// planned read window cannot diverge from the expression we evaluate.
pub struct QueryPlan {
  expression : @ast.Expr
  at : Double
  window : (Int64, Int64)?
}

///|
fn exact_ms(value : Double) -> Int64 raise AdapterError {
  if value != value ||
    value < -9007199254740991.0 ||
    value > 9007199254740991.0 ||
    value % 1.0 != 0.0 {
    raise Invalid(
      "timestamps must be integral milliseconds within the exact Double integer range",
    )
  }
  value.to_int64()
}

///|
fn bounds(
  expr : @ast.Expr,
  at : Double,
  result : Ref[(Int64, Int64)?],
  nodes : Ref[Int],
  depth : Int,
) -> Unit raise AdapterError {
  nodes.val += 1
  if nodes.val > 1024 || depth > 64 {
    raise Invalid("query planning node/depth limit")
  }
  match expr {
    Selector(selector) => {
      let end = selector.at_ms.unwrap_or(at) - selector.offset_ms
      // Upstream 0.1.0 instant selectors use a fixed inclusive 5-minute lookback.
      let span = selector.range_ms.unwrap_or(300000.0)
      if span < 0.0 {
        raise Invalid("negative range")
      }
      let start = exact_ms(end - span)
      let end = exact_ms(end)
      result.val = Some(
        match result.val {
          None => (start, end)
          Some((a, b)) =>
            (if start < a { start } else { a }, if end > b { end } else { b })
        },
      )
    }
    Call(_, args) | Aggregate(_, args, _, _) =>
      for arg in args {
        bounds(arg, at, result, nodes, depth + 1)
      }
    Unary(_, arg) => bounds(arg, at, result, nodes, depth + 1)
    Binary(_, left, right, _, _) => {
      bounds(left, at, result, nodes, depth + 1)
      bounds(right, at, result, nodes, depth + 1)
    }
    Number(_) | StringLiteral(_) => ()
  }
}

///|
pub fn plan(query : String, at_ms : Int64) -> QueryPlan raise {
  if query.length() > 4096 {
    raise Invalid("query length limit")
  }
  if at_ms < -9007199254740991L || at_ms > 9007199254740991L {
    raise Invalid("evaluation time loses precision")
  }
  let expression = @parser.parse(query)
  let window = Ref(None)
  bounds(expression, at_ms.to_double(), window, Ref(0), 0)
  { expression, at: at_ms.to_double(), window: window.val, }
}

///|
/// Closed conservative union of every selector's required time window, including
/// offset and upstream millisecond @ semantics. Scalar-only queries return None.
pub fn QueryPlan::read_window(self : QueryPlan) -> (Int64, Int64)? {
  self.window
}

///|
/// Convert decoded archive samples; archive timestamps must already be ms.
/// Nonfinite bits (including stale markers) are rejected, never dropped.
pub fn series(
  metric : String,
  labels : Array[(String, String)],
  samples : Array[@archive.Sample],
) -> @model.Series raise AdapterError {
  if metric.is_empty() ||
    metric.length() > 256 ||
    labels.length() > 64 ||
    samples.length() > 100000 {
    raise Invalid("series metadata/sample limit")
  }
  let seen : Map[String, Bool] = Map([])
  for (key, value) in labels {
    if key.is_empty() ||
      key == "__name__" ||
      key.length() > 256 ||
      value.length() > 1024 ||
      seen.contains(key) {
      raise Invalid("duplicate/reserved/invalid label")
    }
    seen[key] = true
  }
  let output : Array[@model.Sample] = []
  let mut previous : Int64? = None
  for sample in samples {
    if sample.timestamp < -9007199254740991L ||
      sample.timestamp > 9007199254740991L {
      raise Invalid("sample timestamp loses precision")
    }
    match previous {
      Some(t) if sample.timestamp <= t =>
        raise Invalid("samples must be strictly increasing")
      _ => ()
    }
    if (sample.bits & 0x7ff0000000000000UL) == 0x7ff0000000000000UL {
      raise Invalid(
        "nonfinite/stale value is unsupported by this query adapter",
      )
    }
    output.push({
      timestamp: sample.timestamp.to_double(),
      value: sample.bits.reinterpret_as_int64().reinterpret_as_double(),
    })
    previous = Some(sample.timestamp)
  }
  @model.Series::new(metric, @model.LabelSet::new(labels), output)
}

///|
/// Query semantics are entirely upstream. The caller must supply every relevant
/// series and read the complete read_window; this is not a TSDB discovery API.
pub fn QueryPlan::evaluate(
  self : QueryPlan,
  series : Array[@model.Series],
) -> @model.Value raise @model.PromqlError {
  @eval.evaluate(self.expression, @eval.EvalContext::new(series, self.at))
}
