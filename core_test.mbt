///|
test "empty canonical bytes" {
  assert_eq(@gorilla.encode([]), b"GOR1\x00\x00\x00\x00")
  assert_eq(@gorilla.decode(b"GOR1\x00\x00\x00\x00"), [])
}

///|
test "one sample fixed wire" {
  let s : Array[@gorilla.Sample] = [{ timestamp: 1L, bits: 2UL, }]
  assert_eq(
    @gorilla.encode(s),
    b"GOR1\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x02",
  )
}

///|
test "zero XOR compresses constant series" {
  let s = Array::makei(1000, i => @gorilla.Sample::{
    timestamp: i.to_int64() * 60L,
    bits: 0x3ff0000000000000UL,
  })
  let bytes = @gorilla.encode(s)
  assert_eq(@gorilla.decode(bytes), s)
  assert_true(bytes.length() < 400)
}

///|
test "all float bit patterns and irregular timestamp classes" {
  let bits = [
    0UL, 0x8000000000000000UL, 0x7ff0000000000000UL, 0xfff0000000000000UL, 0x7ff8000000000001UL,
    1UL, 0xffffffffffffffffUL,
  ]
  let times = [0L, 1L, 65L, 320L, 2368L, 2368L, 100000000000L]
  let s = Array::makei(bits.length(), i => @gorilla.Sample::{
    timestamp: times[i],
    bits: bits[i],
  })
  assert_eq(@gorilla.decode(@gorilla.encode(s)), s)
}

///|
test "random raw bits lossless" {
  let mut x = 17UL
  let s : Array[@gorilla.Sample] = []
  for i in 0..<2000 {
    x = x * 6364136223846793005UL + 1UL
    s.push({ timestamp: i.to_int64() * 11L, bits: x, })
  }
  assert_eq(@gorilla.decode(@gorilla.encode(s)), s)
}

///|
test "every byte truncation rejected" {
  let wire = @gorilla.encode([
    { timestamp: 0L, bits: 1UL, },
    { timestamp: 60L, bits: 2UL, },
    { timestamp: 120L, bits: 4UL, },
  ])
  for n in 0..<wire.length() {
    assert_true(
      try {
        ignore(@gorilla.decode(Bytes::from_array(wire.to_array()[:n])))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "bad header extra bytes timestamp order rejected" {
  assert_true(
    try {
      ignore(@gorilla.decode(b"BAD!\x00\x00\x00\x00"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@gorilla.decode(@gorilla.encode([]) + b"\x00"))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(
        @gorilla.encode([
          { timestamp: 2L, bits: 0UL, },
          { timestamp: 1L, bits: 0UL, },
        ]),
      )
      false
    } catch {
      _ => true
    },
  )
}
