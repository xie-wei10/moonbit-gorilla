///|
test "dump labels use upstream escaping and normalized series identity" {
  let rows = @moonpromql.parse_promtool_dump(
    "{__name__=\"metric\", room=\"a}b\", q=\"\\\"\\\\\"} -0 -60000\r\n" +
    "{q=\"\\\"\\\\\", room=\"a}b\", __name__=\"metric\"} 1.25e2 0\n",
  )
  assert_eq(rows.length(), 1)
  assert_eq(rows[0].labels, [("q", "\"\\"), ("room", "a}b")])
  assert_eq(rows[0].samples[0].timestamp, -60000L)
  assert_eq(rows[0].samples[0].bits, 0x8000000000000000UL)
  assert_eq(
    rows[0].samples[1].bits,
    125.0.reinterpret_as_int64().reinterpret_as_uint64(),
  )
}

///|
test "dump rejects unsupported and incomplete observations rather than silently skipping" {
  for
    source in [
      "{__name__=\"x\"} NaN 0", "{__name__=\"x\"} 1e999 0", "{__name__=\"x\"} 1 0.5",
      "{__name__=\"x\"} 1 9007199254740992", "{__name__=\"x\"} 1 0\n{__name__=\"x\"} 2 0",
      "{__name__=\"x\"} 1 2\n{__name__=\"x\"} 2 1", "{__name__=\"x\", a=\"b\", a=\"c\"} 1 0",
      "{__name__=\"x\", a=~\"b\"} 1 0", "{a=\"b\"} 1 0", "{__name__=\"x\"} 1", "{__name__=\"x\"} 1 0 trailing",
      "{__name__=\"x\"}1 0", "{__name__=\"x\"} {count:2} 0",
    ] {
    assert_true(
      try {
        ignore(@moonpromql.parse_promtool_dump(source))
        false
      } catch {
        _ => true
      },
    )
  }
  let many = Array::makei(65, i => "{__name__=\"m\{i}\"} 1 0").join("\n")
  assert_true(
    try {
      ignore(@moonpromql.parse_promtool_dump(many))
      false
    } catch {
      _ => true
    },
  )
}
