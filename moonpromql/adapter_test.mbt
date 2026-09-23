///|
test "planner follows upstream range offset at and five minute instant lookback" {
  assert_eq(
    @moonpromql.plan(
      "sum(rate(counter[2m] offset 1m)) + avg_over_time(temp[1m] @ 600000)", 900000L,
    ).read_window(),
    Some((540000L, 840000L)),
  )
  assert_eq(
    @moonpromql.plan("up", 100000L).read_window(),
    Some((-200000L, 100000L)),
  )
  assert_eq(@moonpromql.plan("1 + 2", 0L).read_window(), None)
  assert_true(
    try {
      ignore(@moonpromql.plan("x @ 0.5", 0L))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "compressed samples feed real upstream evaluation with left open range boundary" {
  let samples = [
    for i in 0..<4 => {
      @archive.Sample::{
        timestamp: i.to_int64() * 60000L,
        bits: i.to_double().reinterpret_as_int64().reinterpret_as_uint64(),
      }
    }
  ]
  let decoded = @archive.decode(@archive.encode(samples))
  let plan = @moonpromql.plan("avg_over_time(temperature[2m])", 180000L)
  let whole = @moonpromql.series("temperature", [("room", "A")], samples)
  let cut = @moonpromql.series(
    "temperature",
    [("room", "A")],
    decoded.filter(s => s.timestamp >= 60000L),
  )
  assert_eq(plan.evaluate([whole]), plan.evaluate([cut]))
  match plan.evaluate([cut]) {
    Instant(points) => assert_eq(points[0].value, 2.5)
    _ => fail("expected vector")
  }
}

///|
test "query adaptation preserves negative zero but rejects lossy time stale nan and duplicates" {
  let negative_zero : @archive.Sample = {
    timestamp: 0L,
    bits: 9223372036854775808UL,
  }
  let series = @moonpromql.series("x", [], [negative_zero])
  assert_eq(
    series.samples[0].value.reinterpret_as_int64().reinterpret_as_uint64(),
    negative_zero.bits,
  )
  for
    bits in [
      0x7ff0000000000000UL, 0xfff0000000000000UL, 0x7ff0000000000002UL, 0x7ff8000000000042UL,
    ] {
    assert_true(
      try {
        ignore(@moonpromql.series("x", [], [{ timestamp: 0L, bits, }]))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(
        @moonpromql.series("x", [], [
          { timestamp: 9007199254740992L, bits: 0UL, },
        ]),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpromql.series("x", [], [negative_zero, negative_zero]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpromql.series("x", [("job", "a"), ("job", "b")], []))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@moonpromql.series("x", [("__name__", "other")], []))
      false
    } catch {
      _ => true
    },
  )
}
