///|
fn archive_fixture(
  samples : Array[@gorilla.Sample],
  block_size : Int,
) -> Bytes raise {
  let encoder = @gorilla.ArchiveEncoder::new(block_size~)
  let chunks = [@gorilla.archive_header()]
  for sample in samples {
    if encoder.append(sample) is Some(bytes) {
      chunks.push(bytes)
    }
  }
  let tail = encoder.finish()
  assert_eq(encoder.finish(), tail)
  chunks.push(tail)
  let bytes = []
  for chunk in chunks {
    for byte in chunk {
      bytes.push(byte)
    }
  }
  Bytes::from_array(bytes)
}

///|
fn fixture_index(bytes : Bytes) -> @gorilla.ArchiveIndex raise {
  let length = @gorilla.archive_index_length(
    bytes[bytes.length() - 12:].to_owned(),
  )
  @gorilla.ArchiveIndex::new(
    bytes[bytes.length() - 12 - length:bytes.length() - 12].to_owned(),
    bytes.length().to_uint64(),
  )
}

///|
test "Prometheus XOR full timestamp domain raw IEEE bits snapshots and strict tail" {
  let samples : Array[@gorilla.Sample] = [
    { timestamp: -9223372036854775808L, bits: 0x7ff0000000000001UL, },
    { timestamp: 9223372036854775807L, bits: 0x8000000000000000UL, },
    { timestamp: -1L, bits: 0xfff0000000000000UL, },
    { timestamp: 0L, bits: 0UL, },
  ]
  let encoder = @gorilla.XorEncoder::new()
  encoder.append(samples[0])
  let prefix = encoder.snapshot()
  for i in 1..<samples.length() {
    encoder.append(samples[i])
  }
  let bytes = encoder.finish()
  assert_eq(encoder.finish(), bytes)
  assert_eq(encoder.encoded_size(), bytes.length())
  assert_eq(@gorilla.decode_xor(prefix), [samples[0]])
  assert_eq(@gorilla.decode_xor(bytes), samples)
  assert_true(
    try {
      encoder.append(samples[0])
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(@gorilla.decode_xor(bytes + b"\x00"))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(@gorilla.decode_xor(bytes + b"\xff", strict=false), samples)
  for cut in 0..<bytes.length() {
    assert_true(
      try {
        ignore(@gorilla.decode_xor(bytes[:cut].to_owned()))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "GOR2 arbitrary byte fragmentation complete index and timestamp boundary queries" {
  assert_eq(@gorilla.crc32(b"123456789"), 0xcbf43926U)
  let samples = Array::makei(73, i => @gorilla.Sample::{
    timestamp: (i / 3 - 12).to_int64(),
    bits: (i % 9).to_uint64() ^ 0x7ff8000000000000UL,
  })
  let bytes = archive_fixture(samples, 7)
  let index = fixture_index(bytes)
  assert_eq(index.entries().length(), 11)
  let entries = index.entries()
  let selected = index.select(-2L, 2L)
  let found = []
  for i in selected {
    let entry = entries[i]
    let start = entry.offset.to_int()
    let values = index.decode_block(
      i,
      bytes[start:start + entry.length].to_owned(),
    )
    for sample in values {
      if sample.timestamp >= -2L && sample.timestamp <= 2L {
        found.push(sample)
      }
    }
  }
  assert_eq(found, samples.filter(s => s.timestamp >= -2L && s.timestamp <= 2L))
  assert_eq(index.select(-100L, -99L), [])
  assert_eq(index.select(100L, 101L), [])
  for size in [1, 2, 3, 7, 28, 31, 64, 511] {
    let decoder = @gorilla.ArchiveDecoder::new()
    let result = []
    let mut pos = 0
    while pos < bytes.length() {
      let end = Int::min(pos + size, bytes.length())
      for sample in decoder.feed(bytes[pos:end].to_owned()) {
        result.push(sample)
      }
      pos = end
    }
    decoder.finish()
    assert_true(decoder.is_verified())
    assert_eq(decoder.buffered_bytes(), 0)
    assert_eq(result, samples)
    assert_eq(decoder.feed(b""), [])
  }
}

///|
test "GOR2 truncation corruption wrong index and failed state are observable" {
  let samples = Array::makei(9, i => @gorilla.Sample::{
    timestamp: i.to_int64(),
    bits: i.to_uint64(),
  })
  let bytes = archive_fixture(samples, 4)
  for cut in 0..<bytes.length() {
    let decoder = @gorilla.ArchiveDecoder::new()
    assert_true(
      try {
        ignore(decoder.feed(bytes[:cut].to_owned()))
        decoder.finish()
        false
      } catch {
        _ => true
      },
    )
    assert_true(
      try {
        ignore(decoder.feed(b""))
        false
      } catch {
        _ => true
      },
    )
  }
  for at in [0, 8, 16, 25, 40, bytes.length() - 20, bytes.length() - 1] {
    let damaged = bytes.to_array()
    damaged[at] = (damaged[at].to_int() ^ 1).to_byte()
    let decoder = @gorilla.ArchiveDecoder::new()
    assert_true(
      try {
        ignore(decoder.feed(Bytes::from_array(damaged)))
        decoder.finish()
        false
      } catch {
        _ => true
      },
    )
    assert_true(!decoder.is_verified())
  }
  let decoder = @gorilla.ArchiveDecoder::new()
  ignore(decoder.feed(bytes))
  decoder.finish()
  assert_true(
    try {
      ignore(decoder.feed(b"x"))
      false
    } catch {
      _ => true
    },
  )
  let index = fixture_index(bytes)
  let a = index.entries()[0]
  let b = index.entries()[1]
  assert_true(
    try {
      ignore(
        index.decode_block(
          1,
          bytes[a.offset.to_int():a.offset.to_int() + a.length].to_owned(),
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  assert_true(b.offset > a.offset)
}

///|
test "GOR2 empty stream encoder order rejection and block size boundaries" {
  let bytes = archive_fixture([], 2)
  assert_eq(bytes.length(), 32)
  assert_eq(fixture_index(bytes).entries(), [])
  let decoder = @gorilla.ArchiveDecoder::new()
  assert_eq(decoder.feed(bytes), [])
  decoder.finish()
  for size in [0, 65536] {
    assert_true(
      try {
        ignore(@gorilla.ArchiveEncoder::new(block_size=size))
        false
      } catch {
        _ => true
      },
    )
  }
  let encoder = @gorilla.ArchiveEncoder::new(block_size=1)
  let frame = encoder.append({ timestamp: 7L, bits: 1UL, }).unwrap()
  assert_eq(encoder.blocks_written(), 1)
  assert_true(
    try {
      ignore(encoder.append({ timestamp: 6L, bits: 2UL, }))
      false
    } catch {
      _ => true
    },
  )
  let decoder = @gorilla.ArchiveDecoder::new()
  assert_eq(
    decoder.feed(@gorilla.archive_header() + frame + encoder.finish()),
    [{ timestamp: 7L, bits: 1UL, }],
  )
  decoder.finish()
  assert_true(
    try {
      ignore(encoder.append({ timestamp: 8L, bits: 2UL, }))
      false
    } catch {
      _ => true
    },
  )
}
