///|
test "stream snapshots preserve GOR1 bytes and remain independent" {
  let writer = @gorilla.Encoder::new()
  assert_eq(writer.snapshot(), b"GOR1\x00\x00\x00\x00")
  writer.append({ timestamp: 1L, bits: 2UL, })
  let first = writer.snapshot()
  writer.append({ timestamp: 1L, bits: 2UL, })
  let second = writer.snapshot()
  assert_eq(
    second, b"GOR1\x00\x00\x00\x02\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x02\x00",
  )
  assert_eq(writer.length(), 2)
  assert_eq(writer.encoded_size(), second.length())
  writer.append({ timestamp: 65L, bits: 0x8000000000000000UL, })
  assert_eq(@gorilla.decode(first), [{ timestamp: 1L, bits: 2UL, }])
  assert_eq(@gorilla.decode(second).length(), 2)
  assert_eq(@gorilla.decode(writer.finish()).length(), 3)
  assert_eq(writer.finish(), writer.snapshot())
  assert_true(
    try {
      writer.append({ timestamp: 66L, bits: 0UL, })
      false
    } catch {
      _ => true
    },
  )
}

///|
test "stream invalid append does not change accepted prefix" {
  let writer = @gorilla.Encoder::new()
  writer.append({ timestamp: 10L, bits: 0UL, })
  let before = writer.snapshot()
  for timestamp in [-1L, 9L, 9007199254740992L] {
    assert_true(
      try {
        writer.append({ timestamp, bits: 999UL, })
        false
      } catch {
        _ => true
      },
    )
    assert_eq(writer.snapshot(), before)
    assert_eq(writer.length(), 1)
  }
  writer.append({ timestamp: 10L, bits: 1UL, })
  assert_eq(@gorilla.decode(writer.finish())[1].bits, 1UL)
}

///|
test "stream incremental decoding and draining validate the complete block" {
  let data = @gorilla.encode([
    { timestamp: 0L, bits: 1UL, },
    { timestamp: 60L, bits: 2UL, },
    { timestamp: 120L, bits: 4UL, },
  ])
  let reader = @gorilla.Decoder::new(data)
  assert_eq(reader.remaining(), 3)
  assert_false(reader.is_verified())
  assert_eq(reader.next(), Some({ timestamp: 0L, bits: 1UL, }))
  assert_eq(reader.remaining(), 2)
  reader.finish()
  assert_true(reader.is_verified())
  assert_eq(reader.next(), None)
  reader.finish()
  let invalid = @gorilla.Decoder::new(data + b"\x00")
  assert_eq(invalid.next(), Some({ timestamp: 0L, bits: 1UL, }))
  assert_true(
    try {
      invalid.finish()
      false
    } catch {
      _ => true
    },
  )
  assert_false(invalid.is_verified())
  assert_true(
    try {
      ignore(invalid.next())
      false
    } catch {
      _ => true
    },
  )
  // Even a range that excludes the corrupt suffix must still report corruption.
  assert_true(
    try {
      ignore(@gorilla.decode_range(data + b"\x00", 0L, 0L))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "stream padding and every truncation fail instead of producing EOF" {
  let wire = @gorilla.encode([
    { timestamp: 0L, bits: 0UL, },
    { timestamp: 0L, bits: 0UL, },
  ])
  let bytes = wire.to_array()
  bytes[bytes.length() - 1] = (1).to_byte()
  let bad = @gorilla.Decoder::new(Bytes::from_array(bytes))
  ignore(bad.next())
  assert_true(
    try {
      ignore(bad.next())
      false
    } catch {
      _ => true
    },
  )
  for count in 0..<wire.length() {
    assert_true(
      try {
        @gorilla.Decoder::new(Bytes::from_array(wire.to_array()[:count])).finish()
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "stream maximum block uses packed storage and preserves all samples" {
  let writer = @gorilla.Encoder::new()
  for i in 0..<100000 {
    writer.append({ timestamp: i.to_int64(), bits: 0x7ff8000000000001UL, })
  }
  assert_true(writer.encoded_size() < 26000)
  assert_true(
    try {
      writer.append({ timestamp: 100000L, bits: 0UL, })
      false
    } catch {
      _ => true
    },
  )
  let reader = @gorilla.Decoder::new(writer.finish())
  let mut count = 0
  while reader.next() is Some(sample) {
    assert_eq(sample.timestamp, count.to_int64())
    assert_eq(sample.bits, 0x7ff8000000000001UL)
    count += 1
  }
  assert_eq(count, 100000)
  assert_true(reader.is_verified())
}
