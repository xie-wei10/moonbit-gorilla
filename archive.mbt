///|
/// One independently checksummed Prometheus XOR payload in a GOR2 archive.
pub(all) struct BlockInfo {
  offset : UInt64
  length : Int
  count : Int
  first : Int64
  last : Int64
  checksum : UInt
} derive(Debug, Eq)

///|
let crc_table : Array[UInt] = Array::makei(256, i => {
  let mut value = i.reinterpret_as_uint()
  for _ in 0..<8 {
    value = if (value & 1U) == 1U {
      (value >> 1) ^ 0xedb88320U
    } else {
      value >> 1
    }
  }
  value
})

///|
/// IEEE CRC-32, matching the standard zlib/ZIP CRC polynomial and initialization.
pub fn crc32(bytes : Bytes) -> UInt {
  let mut crc = 0xffffffffU
  for b in bytes {
    crc = (crc >> 8) ^
      crc_table[((crc ^ b.to_uint()) & 255U).reinterpret_as_int()]
  }
  crc ^ 0xffffffffU
}

///|
fn archive_put(out : Array[Byte], value : UInt64, width : Int) -> Unit {
  for i = width - 1; i >= 0; i = i - 1 {
    out.push(((value >> (8 * i)) & 255UL).to_byte())
  }
}

///|
fn archive_get(
  bytes : Bytes,
  offset : Int,
  width : Int,
) -> UInt64 raise CodecError {
  if offset < 0 || offset + width > bytes.length() {
    raise Invalid("truncated archive metadata")
  }
  let mut value = 0UL
  for i in 0..<width {
    value = (value << 8) | bytes[offset + i].to_uint64()
  }
  value
}

///|
pub fn archive_header() -> Bytes {
  b"GOR2\x01\x00\x00\x00"
}

///|
fn archive_frame_header(
  bytes : Bytes,
  offset : UInt64,
) -> BlockInfo raise CodecError {
  if archive_get(bytes, 0, 4) != 0x424c4b32UL {
    raise Invalid("invalid block marker")
  }
  let count = archive_get(bytes, 4, 4)
  let length = archive_get(bytes, 8, 4)
  if count == 0UL || count > 65535UL || length < 2UL || length > 2000000UL {
    raise Invalid("archive block limits")
  }
  let first = archive_get(bytes, 12, 8).reinterpret_as_int64()
  let last = archive_get(bytes, 20, 8).reinterpret_as_int64()
  if last < first {
    raise Invalid("unordered block bounds")
  }
  {
    offset,
    length: length.to_int() + 32,
    count: count.to_int(),
    first,
    last,
    checksum: 0U,
  }
}

///|
fn archive_frame_info(
  bytes : Bytes,
  offset : UInt64,
) -> BlockInfo raise CodecError {
  let info = archive_frame_header(bytes, offset)
  if bytes.length() != info.length {
    raise Invalid("block byte length mismatch")
  }
  let expected = archive_get(bytes, bytes.length() - 4, 4).to_uint()
  if crc32(bytes[:bytes.length() - 4].to_owned()) != expected {
    raise Invalid("block checksum mismatch")
  }
  { ..info, checksum: expected, }
}

///|
fn archive_samples(
  frame : Bytes,
  info : BlockInfo,
) -> Array[Sample] raise CodecError {
  let payload = frame[28:frame.length() - 4].to_owned()
  let decoder = XorDecoder::new(payload)
  let result = []
  let mut previous : Int64? = None
  while decoder.next() is Some(sample) {
    if previous is Some(t) && sample.timestamp < t {
      raise Invalid("unordered archive samples")
    }
    previous = Some(sample.timestamp)
    result.push(sample)
  }
  if result.length() != info.count ||
    result[0].timestamp != info.first ||
    result[result.length() - 1].timestamp != info.last {
    raise Invalid("block sample metadata mismatch")
  }
  result
}

///|
pub struct ArchiveEncoder {
  priv block_size : Int
  priv mut chunk : XorEncoder
  priv entries : Array[BlockInfo]
  priv mut offset : UInt64
  priv mut first : Int64
  priv mut previous : Int64?
  priv mut closed : Bytes?
}

///|
pub fn ArchiveEncoder::new(
  block_size? : Int = 4096,
) -> ArchiveEncoder raise CodecError {
  if block_size < 1 || block_size > 65535 {
    raise Invalid("block_size must be 1..65535")
  }
  {
    block_size,
    chunk: XorEncoder::new(),
    entries: [],
    offset: 8UL,
    first: 0L,
    previous: None,
    closed: None,
  }
}

///|
fn ArchiveEncoder::flush(self : ArchiveEncoder) -> Bytes {
  let payload = self.chunk.finish()
  let out : Array[Byte] = [0x42, 0x4c, 0x4b, 0x32]
  archive_put(out, self.chunk.length().to_uint64(), 4)
  archive_put(out, payload.length().to_uint64(), 4)
  archive_put(out, self.first.reinterpret_as_uint64(), 8)
  archive_put(out, self.previous.unwrap().reinterpret_as_uint64(), 8)
  for b in payload {
    out.push(b)
  }
  let checksum = crc32(Bytes::from_array(out))
  archive_put(out, checksum.to_uint64(), 4)
  let info : BlockInfo = {
    offset: self.offset,
    length: out.length(),
    count: self.chunk.length(),
    first: self.first,
    last: self.previous.unwrap(),
    checksum,
  }
  self.entries.push(info)
  self.offset += out.length().to_uint64()
  self.chunk = XorEncoder::new()
  Bytes::from_array(out)
}

///|
/// Return a completed block when full. The caller writes archive_header() once,
/// each returned block immediately, then finish()'s final block/index/trailer.
pub fn ArchiveEncoder::append(
  self : ArchiveEncoder,
  sample : Sample,
) -> Bytes? raise CodecError {
  if self.closed is Some(_) {
    raise Invalid("archive encoder finished")
  }
  if self.entries.length() >= 65536 {
    raise Invalid("archive block count limit")
  }
  if self.previous is Some(t) && sample.timestamp < t {
    raise Invalid("archive timestamps must be nondecreasing")
  }
  if self.chunk.length() == 0 {
    self.first = sample.timestamp
  }
  self.chunk.append(sample)
  self.previous = Some(sample.timestamp)
  if self.chunk.length() == self.block_size {
    Some(self.flush())
  } else {
    None
  }
}

///|
pub fn ArchiveEncoder::finish(self : ArchiveEncoder) -> Bytes {
  if self.closed is Some(bytes) {
    return bytes
  }
  let tail = if self.chunk.length() > 0 { self.flush() } else { b"" }
  let out : Array[Byte] = [0x49, 0x44, 0x58, 0x32]
  archive_put(out, self.entries.length().to_uint64(), 4)
  for entry in self.entries {
    archive_put(out, entry.offset, 8)
    archive_put(out, entry.length.to_uint64(), 4)
    archive_put(out, entry.count.to_uint64(), 4)
    archive_put(out, entry.first.reinterpret_as_uint64(), 8)
    archive_put(out, entry.last.reinterpret_as_uint64(), 8)
    archive_put(out, entry.checksum.to_uint64(), 4)
  }
  archive_put(out, crc32(Bytes::from_array(out)).to_uint64(), 4)
  let index_length = out.length()
  archive_put(out, index_length.to_uint64(), 8)
  archive_put(out, 0x454e4432UL, 4)
  let result = tail + Bytes::from_array(out)
  self.closed = Some(result)
  result
}

///|
pub fn ArchiveEncoder::blocks_written(self : ArchiveEncoder) -> Int {
  self.entries.length()
}

///|
pub struct ArchiveIndex {
  priv blocks : Array[BlockInfo]
  priv size : UInt64
}

///|
/// Parse the last 12 bytes without trusting an unchecked length for allocation.
pub fn archive_index_length(trailer : Bytes) -> Int raise CodecError {
  if trailer.length() != 12 || archive_get(trailer, 8, 4) != 0x454e4432UL {
    raise Invalid("invalid archive trailer")
  }
  let length = archive_get(trailer, 0, 8)
  if length < 12UL || length > 2359308UL || (length - 12UL) % 36UL != 0UL {
    raise Invalid("archive index length limit")
  }
  length.to_int()
}

///|
pub fn ArchiveIndex::new(
  index : Bytes,
  file_size : UInt64,
) -> ArchiveIndex raise CodecError {
  if index.length() < 12 ||
    index.length() > 2359308 ||
    archive_get(index, 0, 4) != 0x49445832UL {
    raise Invalid("invalid archive index")
  }
  let count = archive_get(index, 4, 4)
  if count > 65536UL || index.length() != 12 + count.to_int() * 36 {
    raise Invalid("archive index count/length mismatch")
  }
  if crc32(index[:index.length() - 4].to_owned()) !=
    archive_get(index, index.length() - 4, 4).to_uint() {
    raise Invalid("archive index checksum mismatch")
  }
  let blocks = []
  let mut next_offset = 8UL
  let mut previous : Int64? = None
  for i in 0..<count.to_int() {
    let p = 8 + i * 36
    let offset = archive_get(index, p, 8)
    let length = archive_get(index, p + 8, 4)
    let count = archive_get(index, p + 12, 4)
    let first = archive_get(index, p + 16, 8).reinterpret_as_int64()
    let last = archive_get(index, p + 24, 8).reinterpret_as_int64()
    let checksum = archive_get(index, p + 32, 4).to_uint()
    if offset != next_offset ||
      length < 34UL ||
      length > 2000032UL ||
      count == 0UL ||
      count > 65535UL ||
      last < first {
      raise Invalid("invalid block index entry")
    }
    if previous is Some(t) && first < t {
      raise Invalid("unordered block index")
    }
    blocks.push(BlockInfo::{
      offset,
      length: length.to_int(),
      count: count.to_int(),
      first,
      last,
      checksum,
    })
    next_offset += length
    previous = Some(last)
  }
  if file_size != next_offset + index.length().to_uint64() + 12UL {
    raise Invalid("index/file size mismatch")
  }
  { blocks, size: file_size, }
}

///|
pub fn ArchiveIndex::entries(self : ArchiveIndex) -> Array[BlockInfo] {
  self.blocks.copy()
}

///|
pub fn ArchiveIndex::file_size(self : ArchiveIndex) -> UInt64 {
  self.size
}

///|
/// Closed timestamp interval. Binary search skips blocks ending before start.
pub fn ArchiveIndex::select(
  self : ArchiveIndex,
  start : Int64,
  end : Int64,
) -> Array[Int] raise CodecError {
  if end < start {
    raise Invalid("invalid query interval")
  }
  let mut lo = 0
  let mut hi = self.blocks.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if self.blocks[mid].last < start {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  let result = []
  while lo < self.blocks.length() && self.blocks[lo].first <= end {
    result.push(lo)
    lo += 1
  }
  result
}

///|
pub fn ArchiveIndex::decode_block(
  self : ArchiveIndex,
  index : Int,
  frame : Bytes,
) -> Array[Sample] raise CodecError {
  let expected = match self.blocks.get(index) {
    Some(info) => info
    None => raise Invalid("block index out of range")
  }
  let actual = archive_frame_info(frame, expected.offset)
  if actual != expected {
    raise Invalid("block does not match index")
  }
  archive_samples(frame, actual)
}

///|
/// Incremental GOR2 input. feed() checks each emitted block; finish() is required
/// to establish that the final index/trailer agree with the entire stream.
pub struct ArchiveDecoder {
  priv buffer : Array[Byte]
  priv entries : Array[BlockInfo]
  priv mut cursor : Int
  priv mut offset : UInt64
  priv mut header : Bool
  priv mut done_ : Bool
  priv mut failed : Bool
}

///|
pub fn ArchiveDecoder::new() -> ArchiveDecoder {
  {
    buffer: [],
    entries: [],
    cursor: 0,
    offset: 0UL,
    header: false,
    done_: false,
    failed: false,
  }
}

///|
pub fn ArchiveDecoder::feed(
  self : ArchiveDecoder,
  data : Bytes,
) -> Array[Sample] raise CodecError {
  if self.failed {
    raise Invalid("archive decoder is in failed state")
  }
  errdefer {
    self.failed = true
  }
  if data.length() > 65536 {
    raise Invalid("feed byte limit 65536")
  }
  if self.done_ {
    if !data.is_empty() {
      raise Invalid("trailing archive bytes")
    }
    return []
  }
  for b in data {
    self.buffer.push(b)
  }
  let samples = []
  while true {
    let available = self.buffer.length() - self.cursor
    if !self.header {
      if available < 8 {
        break
      }
      let bytes = Bytes::from_array(self.buffer[self.cursor:self.cursor + 8])
      if bytes != archive_header() {
        raise Invalid("invalid archive header/version")
      }
      self.cursor += 8
      self.offset = 8UL
      self.header = true
      continue
    }
    if available < 8 {
      break
    }
    let prefix = Bytes::from_array(
      self.buffer[self.cursor:self.cursor + Int::min(28, available)],
    )
    let marker = archive_get(prefix, 0, 4)
    if marker == 0x424c4b32UL {
      if available < 28 {
        break
      }
      if self.entries.length() >= 65536 {
        raise Invalid("archive block count limit")
      }
      let info = archive_frame_header(prefix, self.offset)
      if available < info.length {
        break
      }
      let frame = Bytes::from_array(
        self.buffer[self.cursor:self.cursor + info.length],
      )
      let info = archive_frame_info(frame, self.offset)
      if self.entries.last() is Some(previous) && info.first < previous.last {
        raise Invalid("unordered archive blocks")
      }
      let block = archive_samples(frame, info)
      for sample in block {
        samples.push(sample)
      }
      if samples.length() > 1000000 {
        raise Invalid("feed sample output limit")
      }
      self.entries.push(info)
      self.cursor += info.length
      self.offset += info.length.to_uint64()
    } else if marker == 0x49445832UL {
      let count = archive_get(prefix, 4, 4)
      if count > 65536UL {
        raise Invalid("archive index count limit")
      }
      let length = 12 + count.to_int() * 36
      if available < length + 12 {
        break
      }
      let index = Bytes::from_array(
        self.buffer[self.cursor:self.cursor + length],
      )
      let trailer = Bytes::from_array(
        self.buffer[self.cursor + length:self.cursor + length + 12],
      )
      if archive_index_length(trailer) != length {
        raise Invalid("index/trailer length mismatch")
      }
      let parsed = ArchiveIndex::new(
        index,
        self.offset + length.to_uint64() + 12UL,
      )
      if parsed.blocks != self.entries {
        raise Invalid("index does not describe stream blocks")
      }
      self.cursor += length + 12
      self.offset += length.to_uint64() + 12UL
      if self.cursor != self.buffer.length() {
        raise Invalid("trailing archive bytes")
      }
      self.done_ = true
      break
    } else {
      raise Invalid("unknown archive record")
    }
  }
  if self.cursor > 0 {
    let remaining = self.buffer[self.cursor:].to_owned()
    self.buffer.clear()
    for b in remaining {
      self.buffer.push(b)
    }
    self.cursor = 0
  }
  samples
}

///|
pub fn ArchiveDecoder::finish(self : ArchiveDecoder) -> Unit raise CodecError {
  if self.failed {
    raise Invalid("archive decoder is in failed state")
  }
  if !self.done_ {
    self.failed = true
    raise Invalid("truncated archive")
  }
}

///|
pub fn ArchiveDecoder::is_verified(self : ArchiveDecoder) -> Bool {
  self.done_ && !self.failed
}

///|
pub fn ArchiveDecoder::buffered_bytes(self : ArchiveDecoder) -> Int {
  self.buffer.length() - self.cursor
}
