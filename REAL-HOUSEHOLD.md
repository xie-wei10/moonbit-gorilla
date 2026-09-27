# UCI household power: complete-source scan, one-month archive, offline query

This consumer demonstrates a concrete file-to-query path for one real, public time series. It does not claim to replace Parquet, Prometheus TSDB, or a hosted monitoring service.

The source is the UCI [Individual Household Electric Power Consumption](https://archive.ics.uci.edu/dataset/235/individual%2Bhousehold%2Belectric%2Bpower%2Bconsumption) dataset (Hebrail & Berard, 2006, DOI [10.24432/C58K54](https://doi.org/10.24432/C58K54)), licensed CC BY 4.0. The original ZIP/text stays outside the repository. The scripts stream the complete distributed text, verify its row count and pinned SHA-256 (`4259c9d7ece5dbee9ab8d53682baac68d791c864f0f64a52b4043cb3b90894b7`), and encode only the full April 2007 month for `Global_active_power` (kW). The importer writes to a hidden staging archive and exposes the final `.gor2` filename only after the complete input matches the pinned source digest.

UCI documents 2,075,259 observations, 9 features, one-minute sampling, and missing measurements. The source file uses semicolon-separated rows; this import accepts the observed single-digit date/month spellings, treats both `?` and an empty selected field as missing, and never turns either into zero. It requires all 43,200 April wall-clock rows to be present once per minute. Missing power values are omitted from the archive so a later query sees a time gap.

The source has no declared timezone in the dataset fields. The importer maps Gregorian date/time fields to an integer millisecond coordinate using UTC calendar arithmetic solely to obtain a stable numeric axis; reports call it a wall-clock coordinate and make no UTC assertion.

## Reproduce

Use a current MoonBit toolchain and Node.js. Obtain the UCI file from its official dataset page and keep the ZIP/extracted text outside this repository. From the repository root, build the existing JS bridge once, then run the streaming importer with a new output directory:

```powershell
moon build --target js
node tools/refresh-engines.mjs
New-Item -ItemType Directory -Force D:\CodexLocal\ban\work\uci-household | Out-Null
Invoke-WebRequest -Uri 'https://archive.ics.uci.edu/static/public/235/individual%2Bhousehold%2Belectric%2Bpower%2Bconsumption.zip' -OutFile D:\CodexLocal\ban\work\uci-household\uci-household.zip
Expand-Archive D:\CodexLocal\ban\work\uci-household\uci-household.zip -DestinationPath D:\CodexLocal\ban\work\uci-household\source
node tools/import-uci-household.mjs D:\CodexLocal\ban\work\uci-household\source\household_power_consumption.txt D:\CodexLocal\ban\work\uci-household\run
python tools/verify-uci-household.py --source D:\CodexLocal\ban\work\uci-household\source\household_power_consumption.txt --run-dir D:\CodexLocal\ban\work\uci-household\run
```

The output directory must not already exist. `run.json` records the full-source digest, selected month and archive digests, query expressions, and indexed-read accounting. `oracle.json` is written only after an independent Python standard-library scan confirms those facts and checks the query results. The checked-in evidence includes the small GOR2 archive and both reports, but not the 133 MB source text.

The consumer chooses the first April 30-minute window containing both a measured and missing `Global_active_power` row. Queries use the Prometheus [range-vector interval `(start, end]`](https://prometheus.io/docs/prometheus/latest/querying/basics/): `count_over_time`, `avg_over_time`, `min_over_time`, and `max_over_time`. Python recomputes them from the source decimal values after the same binary64 conversion used by the consumer. It also checks one archived source point by timestamp and IEEE-754 bits.

Two targeted windows make boundary and gap behavior explicit. For 2007-04-01 00:30, both the 00:00 left-boundary sample (3.480 kW) and 00:30 right-boundary sample (1.568 kW) exist. The archive reader passes 31 candidates from its conservative closed file range; MoonPromQL and Python agree that `(00:00,00:30]` contains 30 values. Independent counterfactual counts are 31 for a left-closed range and 29 for a right-open range. For the first fully missing window, ending 2007-04-28 00:50, all 30 rows in `(00:20,00:50]` are missing. The closed archive read sees one valid candidate exactly at 00:20, but both `count_over_time` and `avg_over_time` return an empty instant vector after the upstream evaluator excludes that left endpoint. This is no result, not zero or NaN.

The recorded run scanned 2,075,259 rows / 132,960,755 source bytes (SHA-256 `4259c9d7ece5dbee9ab8d53682baac68d791c864f0f64a52b4043cb3b90894b7`). April contributed 43,200 wall-clock rows; 39,477 values were encoded and 3,723 `?` values were left absent. The mixed window was 2007-04-28 00:21 wall-clock: 29 measured samples and one missing row. Python and MoonPromQL agreed on count 29, average 1.1613103448275863 kW, minimum 0.488 kW, and maximum 1.478 kW. Each mixed-window query read 6,316 bytes from the 233,699-byte archive; the endpoint comparison read 6,294 bytes. These are `ArchiveFile.bytesRead` measurements, including index/header/trailer and selected compressed blocks, not whole-process I/O. They are observations for these windows, not a benchmark or general performance claim.

The upstream MoonPromQL evaluator is used unchanged. The query adapter receives only the decoded bounded range and applies its own open-left boundary. One April is the only source period validated; the result does not establish all months, timezone reconstruction, a continuously updated archive, TSDB format compatibility, or production adoption. The existing MoonBit [mizchi/parquet project](https://github.com/mizchi/parquet) is another file-format route; this example demonstrates GOR2's indexed time-range path rather than claiming a format gap or superiority.
