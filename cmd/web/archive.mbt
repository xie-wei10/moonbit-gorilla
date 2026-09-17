///|
priv enum ArchiveSession {
  Encoding(@lib.ArchiveEncoder)
  Decoding(@lib.ArchiveDecoder)
  Indexed(@lib.ArchiveIndex)
}

///|
let archive_sessions : Map[Int, ArchiveSession] = Map([])

///|
let next_archive_id : Ref[Int] = Ref(0)

///|
fn archive_allocate(session : ArchiveSession) -> Int raise Failure {
  if archive_sessions.length() >= 64 {
    raise Failure("archive session limit")
  }
  let id = next_archive_id.val
  next_archive_id.val += 1
  archive_sessions[id] = session
  id
}

///|
fn archive_integer(
  request : Json,
  key : String,
  default? : Int = 0,
) -> Int raise Failure {
  if request is Object(fields) {
    match fields.get(key) {
      None => default
      Some(Number(n, ..)) =>
        if n == n.trunc() && n >= 0.0 && n <= 2147483647.0 {
          n.to_int()
        } else {
          raise Failure("integer out of range")
        }
      _ => raise Failure("expected integer")
    }
  } else {
    raise Failure("expected object")
  }
}

///|
fn block_json(info : @lib.BlockInfo) -> Json {
  {
    "offset": info.offset.to_string().to_json(),
    "length": info.length.to_json(),
    "count": info.count.to_json(),
    "first": info.first.to_string().to_json(),
    "last": info.last.to_string().to_json(),
    "checksum": info.checksum.to_json(),
  }
}

///|
pub fn archive_json(input : String) -> String {
  let mut failed_id : Int? = None
  try {
    if input.length() > 16000000 {
      raise Failure("request limit")
    }
    let request = @json.parse(input)
    let result = match request {
      { "operation": String("encoder"), .. } => {
        let encoder = @lib.ArchiveEncoder::new(
          block_size=archive_integer(request, "blockSize", default=4096),
        )
        Json::object({
          "session": archive_allocate(Encoding(encoder)).to_json(),
          "hex": to_hex(@lib.archive_header()).to_json(),
        })
      }
      { "operation": String("decoder"), .. } =>
        Json::object({
          "session": archive_allocate(Decoding(@lib.ArchiveDecoder::new())).to_json(),
        })
      { "operation": String("indexLength"), "hex": String(hex), .. } =>
        @lib.archive_index_length(from_hex(hex)).to_json()
      {
        "operation": String("index"),
        "hex": String(hex),
        "fileSize": String(size),
        ..
      } => {
        let index = @lib.ArchiveIndex::new(
          from_hex(hex),
          @strconv.parse_uint64(size),
        )
        Json::object({
          "session": archive_allocate(Indexed(index)).to_json(),
          "entries": Json::array(index.entries().map(block_json)),
        })
      }
      { "operation": String("close"), .. } => {
        archive_sessions.remove(archive_integer(request, "session"))
        Json::null()
      }
      { "operation": String(operation), .. } => {
        let id = archive_integer(request, "session")
        let session = match archive_sessions.get(id) {
          Some(s) => s
          None => raise Failure("unknown archive session")
        }
        match (session, operation, request) {
          (Encoding(encoder), "append", { "samples": samples, .. }) => {
            failed_id = Some(id)
            let out = []
            for sample in read_samples(samples) {
              if encoder.append(sample) is Some(frame) {
                out.push(to_hex(frame).to_json())
              }
            }
            Json::array(out)
          }
          (Encoding(encoder), "finish", _) => {
            let bytes = encoder.finish()
            archive_sessions.remove(id)
            to_hex(bytes).to_json()
          }
          (Decoding(decoder), "feed", { "hex": String(hex), .. }) => {
            failed_id = Some(id)
            Json::array(decoder.feed(from_hex(hex)).map(sample_json))
          }
          (Decoding(decoder), "finish", _) => {
            failed_id = Some(id)
            decoder.finish()
            archive_sessions.remove(id)
            Json::null()
          }
          (
            Indexed(index),
            "select",
            { "start": String(start), "end": String(end), .. },
          ) =>
            index
            .select(@strconv.parse_int64(start), @strconv.parse_int64(end))
            .to_json()
          (Indexed(index), "block", { "hex": String(hex), .. }) =>
            Json::array(
              index
              .decode_block(archive_integer(request, "index"), from_hex(hex))
              .map(sample_json),
            )
          _ => raise Failure("invalid archive operation")
        }
      }
      _ => raise Failure("invalid archive request")
    }
    Json::object({ "ok": true, "result": result }).stringify()
  } catch {
    e => {
      if failed_id is Some(id) {
        archive_sessions.remove(id)
      }
      Json::object({ "ok": false, "error": Repr(e).to_string().to_json() }).stringify()
    }
  }
}
