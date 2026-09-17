// Generated from saved unmodified Prometheus v0.314.0 reference bytes.

///|
test "38 independent Prometheus vectors on every backend" {
  // empty
  {
    let samples : Array[@gorilla.Sample] = []
    let expected = b"\x00\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 0 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x00\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first -1 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: -1L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 1 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 1L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x02\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 63 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 63L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x7e\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 64 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 64L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x80\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first -64 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: -64L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x7f\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first -65 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: -65L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x81\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 8192 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 8192L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x80\x80\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 1700000000000 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 1700000000000L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\x80\xa0\xab\xfe\xf9\x62\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first -9223372036854775808 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: -9223372036854775808L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // first 9223372036854775807 9218868437227405313
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 9223372036854775807L, bits: 9218868437227405313UL, },
    ]
    let expected = b"\x00\x01\xfe\xff\xff\xff\xff\xff\xff\xff\xff\x01\x7f\xf0\x00\x00\x00\x00\x00\x01"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -9223372036854775808/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: -9223372036852775808L, bits: 1UL, },
      { timestamp: 3000000L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x7c\x00\x00\x00\x00\x00\x00\x00\x07\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -524288/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1475712L, bits: 1UL, },
      { timestamp: 1951424L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x7f\xff\xff\xff\xff\xff\xc0\x00\x07\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -524287/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1475713L, bits: 1UL, },
      { timestamp: 1951426L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x74\x00\x00\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -65536/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1934464L, bits: 1UL, },
      { timestamp: 2868928L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x77\x80\x00\x7f\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -65535/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1934465L, bits: 1UL, },
      { timestamp: 2868930L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x68\x00\x0f\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -8192/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1991808L, bits: 1UL, },
      { timestamp: 2983616L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x6f\x00\x07\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -8191/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1991809L, bits: 1UL, },
      { timestamp: 2983618L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x50\x00\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket -1/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 1999999L, bits: 1UL, },
      { timestamp: 2999998L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x5f\xff\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 0/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2000000L, bits: 1UL, },
      { timestamp: 3000000L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x3f\xc2\x00\x00\x00\x01\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 1/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2000001L, bits: 1UL, },
      { timestamp: 3000002L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x40\x00\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 8191/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2008191L, bits: 1UL, },
      { timestamp: 3016382L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x4f\xff\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 8192/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2008192L, bits: 1UL, },
      { timestamp: 3016384L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x50\x00\x7f\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 8193/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2008193L, bits: 1UL, },
      { timestamp: 3016386L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x61\x00\x0f\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 65535/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2065535L, bits: 1UL, },
      { timestamp: 3131070L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x67\xff\xff\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 65536/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2065536L, bits: 1UL, },
      { timestamp: 3131072L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x68\x00\x07\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 65537/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2065537L, bits: 1UL, },
      { timestamp: 3131074L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x70\x80\x00\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 524287/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2524287L, bits: 1UL, },
      { timestamp: 4048574L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x73\xff\xff\xff\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 524288/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2524288L, bits: 1UL, },
      { timestamp: 4048576L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x74\x00\x00\x7f\x84\x00\x00\x00\x02\x00"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 524289/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: 2524289L, bits: 1UL, },
      { timestamp: 4048578L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x78\x00\x00\x00\x00\x00\x40\x00\x0f\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // delta bucket 9223372036854775807/1
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1000000L, bits: 0UL, },
      { timestamp: -9223372036852775809L, bits: 1UL, },
      { timestamp: 2999998L, bits: 1UL, },
    ]
    let expected = b"\x00\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x84\x3d\x7b\xff\xff\xff\xff\xff\xff\xff\xff\xf8\x40\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // xor window 0
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1L, bits: 1UL, },
      { timestamp: 2L, bits: 0UL, },
      { timestamp: 3L, bits: 1UL, },
      { timestamp: 4L, bits: 18446744073709551615UL, },
    ]
    let expected = b"\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xff\x08\x00\x00\x00\x05\x00\x00\x00\x00\x50\x00\x00\x00\x05\x83\xff\xff\xff\xff\xff\xff\xff\xff\xe0"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // xor window 31
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1L, bits: 2147483648UL, },
      { timestamp: 2L, bits: 0UL, },
      { timestamp: 3L, bits: 2147483649UL, },
      { timestamp: 4L, bits: 18446744073709551615UL, },
    ]
    let expected = b"\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xfe\x12\x97\xf8\x50\x00\x00\x00\x2c\x1f\xff\xff\xff\xff\xbf\xff\xff\xff"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // xor window 32
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1L, bits: 4294967296UL, },
      { timestamp: 2L, bits: 0UL, },
      { timestamp: 3L, bits: 4294967297UL, },
      { timestamp: 4L, bits: 18446744073709551615UL, },
    ]
    let expected = b"\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xfe\x0d\x5f\xe1\x80\x00\x00\x00\xb0\x7f\xff\xff\xff\xfd\xff\xff\xff\xfc"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // xor window 63
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: 1L, bits: 9223372036854775808UL, },
      { timestamp: 2L, bits: 0UL, },
      { timestamp: 3L, bits: 9223372036854775809UL, },
      { timestamp: 4L, bits: 18446744073709551615UL, },
    ]
    let expected = b"\x00\x05\x00\x00\x00\x00\x00\x00\x00\x00\x00\x01\xc0\x0d\x58\x00\x80\x00\x00\x00\x00\x00\x00\x01\x4f\xff\xff\xff\xff\xff\xff\xff\xc0"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // timestamp wrap and reverse
  {
    let samples : Array[@gorilla.Sample] = [
      { timestamp: 0L, bits: 0UL, },
      { timestamp: -1L, bits: 1UL, },
      { timestamp: 1L, bits: 9223372036854775808UL, },
      { timestamp: 63L, bits: 4607182418800017408UL, },
      { timestamp: 64L, bits: 9218868437227405312UL, },
      { timestamp: -64L, bits: 18442240474082181120UL, },
      { timestamp: -65L, bits: 9221120237041090561UL, },
      { timestamp: 8192L, bits: 9218868437227405313UL, },
      { timestamp: 1700000000000L, bits: 18446744073709551615UL, },
      { timestamp: -9223372036854775808L, bits: 0UL, },
      { timestamp: 9223372036854775807L, bits: 1UL, },
    ]
    let expected = b"\x00\x0b\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xff\xff\xff\xff\xff\xff\xff\xff\x01\xff\x08\x00\x00\x00\x06\x00\x0f\x00\x10\x00\x00\x00\x00\x00\x00\x00\x30\x07\x95\xff\x80\x00\x00\x00\x00\x00\x05\xfe\x1c\x80\x00\x00\x00\x00\x00\x00\x01\x7e\xff\x40\x00\x00\x00\x00\x00\x00\x00\x40\x3f\xd0\x01\x00\x00\x00\x00\x00\x00\x38\x40\x85\x00\x04\x00\x00\x00\x00\x00\x00\x78\x00\x00\x0c\x5e\x7f\x29\x3d\xfd\x00\x1f\xff\xff\xff\xff\xff\xfd\xef\xff\xff\x9d\x0c\x06\xaa\x00\x17\xff\xff\xff\xff\xff\xff\xff\xff\xc0\x00\x00\xc5\xe7\xf2\xb3\xff\xc0\x00\x00\x00\x00\x00\x00\x00\x20"
    assert_eq(@gorilla.encode_xor(samples), expected)
    assert_eq(@gorilla.decode_xor(expected), samples)
  }
  // seeded irregular 3
  let samples : Array[@gorilla.Sample] = [
    { timestamp: -6286396601268317819L, bits: 2969223658673496405UL, },
    { timestamp: -6286396601267834857L, bits: 4435506067839604856UL, },
    { timestamp: -6286396601268537226L, bits: 4899476696091423491UL, },
    { timestamp: -6286396601267679837L, bits: 8300685949020229501UL, },
    { timestamp: -6286396601267227223L, bits: 15155624678713808476UL, },
    { timestamp: -6286396601267211652L, bits: 15155624678713808476UL, },
    { timestamp: -6286396601266864707L, bits: 6615883097783829155UL, },
    { timestamp: -6286396601267531757L, bits: 9622042755944592780UL, },
    { timestamp: -6286396601267563372L, bits: 8782006864679731220UL, },
    { timestamp: -6286396601268010809L, bits: 13498772922739849302UL, },
    { timestamp: -6286396601268591367L, bits: 13498772922739849302UL, },
    { timestamp: -6286396601269559887L, bits: 9507240307449441265UL, },
    { timestamp: -6286396601270022351L, bits: 7851038513477357808UL, },
    { timestamp: -6286396601269204568L, bits: 2991176634318798441UL, },
    { timestamp: -6286396601269985556L, bits: 72772178178663490UL, },
    { timestamp: -6286396601270359477L, bits: 72772178178663490UL, },
    { timestamp: -6286396601271000100L, bits: 4193778453850394476UL, },
    { timestamp: -6286396601271551532L, bits: 13840012297942776172UL, },
    { timestamp: -6286396601272105344L, bits: 14754705666637314308UL, },
    { timestamp: -6286396601271420120L, bits: 8081777703520739714UL, },
    { timestamp: -6286396601270771425L, bits: 8081777703520739714UL, },
    { timestamp: -6286396601270488434L, bits: 313418067721363597UL, },
  ]
  let expected = b"\x00\x16\xf5\xb9\x91\xfd\xdd\x99\xe2\xbd\xae\x01\x29\x34\xcd\x2f\x99\xeb\x61\x55\x92\xbd\x1d\xc7\xed\x2e\xb6\x1a\xcb\x50\x0e\x4b\x7f\xff\xff\xff\xff\xff\xb7\xa7\x37\x0f\xff\x9c\x19\x57\x00\xdf\x8a\xde\xfc\x00\x00\x00\x00\x00\x5f\x33\x3a\x61\x9f\x0b\xf9\xe1\x70\x78\xfd\xd3\xa5\xb3\x80\x0a\x16\x26\xdb\xca\xc8\xc1\x92\x1e\x95\x4c\xd7\x28\x73\x75\x13\x07\x9d\x8e\x2a\x17\xa9\xff\xff\xff\xff\xff\xff\xfe\x10\xe2\xb6\xf2\xc0\x53\xbe\xfa\xc1\xb9\x7f\x80\x00\x00\x00\x00\x04\xd9\x15\xdf\x8a\xf5\x0b\xd8\x3e\xb6\xb3\x1d\x34\xf6\x56\x14\x55\x96\x16\x1e\xb7\xc2\x17\x6f\xbf\xfb\xa8\x52\x1a\x38\xa5\xc6\xc4\x04\x5d\x53\xa7\xe7\xb8\xc8\xbb\xc1\x3f\x57\x95\x9d\x8e\xc0\x7c\x00\x00\x00\x00\x00\x4e\x23\xde\x45\x76\xb6\xa3\x7c\xbf\xae\x99\xff\xff\xff\xff\xff\xfe\x79\xac\xd8\xa2\x01\x0a\x90\x63\x6f\x68\xaf\x98\xd8\x6d\xd7\xdc\x65\x1d\x98\xe1\x50\xea\xd7\x35\x97\x70\xae\x33\xdf\x44\x5a\x52\x68\x33\x46\xc0\x16\xd6\x90\x66\x95\x3b\xd6\x45\xb4\x03\x47\x80\x00\x00\x00\x00\x09\x73\xfe\x57\x9d\x60\x14\x3b\xab\x53\x10\xda\xe2\x9e\xea\x6b\x78\x9d\x1c\x50\x84\xb9\x2f\x80\x43\xc0"
  assert_eq(@gorilla.encode_xor(samples), expected)
  assert_eq(@gorilla.decode_xor(expected), samples)
}
