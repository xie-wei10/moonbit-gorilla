#!/usr/bin/env python3
"""Independent stdlib oracle for tools/import-uci-household.mjs."""
import argparse
import datetime as dt
import hashlib
import json
import math
import re
import struct
from pathlib import Path

EXPECTED_ROWS = 2_075_259
EXPECTED_SOURCE_SHA256 = "4259c9d7ece5dbee9ab8d53682baac68d791c864f0f64a52b4043cb3b90894b7"
EXPECTED_MONTH_ROWS = 43_200
HEADER = (
    "Date;Time;Global_active_power;Global_reactive_power;Voltage;"
    "Global_intensity;Sub_metering_1;Sub_metering_2;Sub_metering_3"
)
NUMBER = re.compile(r"^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$")
DATE = re.compile(r"^(\d{1,2})/(\d{1,2})/(\d{4})$")
TIME = re.compile(r"^(\d{2}):(\d{2}):(\d{2})$")
EPOCH = dt.datetime(1970, 1, 1)


def wall_clock_ms(year, month, day, hour, minute, second):
    value = dt.datetime(year, month, day, hour, minute, second)
    delta = value - EPOCH
    return (delta.days * 86_400 + delta.seconds) * 1000


def parse_clock(date_text, time_text, line_no):
    d = DATE.fullmatch(date_text)
    t = TIME.fullmatch(time_text)
    if not d or not t:
        raise ValueError(f"line {line_no}: invalid date/time syntax")
    day, month, year = map(int, d.groups())
    hour, minute, second = map(int, t.groups())
    value = dt.datetime(year, month, day, hour, minute, second)
    return value, wall_clock_ms(year, month, day, hour, minute, second)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--run-dir", required=True, type=Path)
    args = parser.parse_args()
    source = args.source.resolve()
    run_dir = args.run_dir.resolve()
    run_path = run_dir / "run.json"
    output_path = run_dir / "oracle.json"
    if output_path.exists():
        raise FileExistsError(f"refusing to overwrite {output_path}")
    run = json.loads(run_path.read_text(encoding="utf-8"))

    digest = hashlib.sha256()
    rows = 0
    power_blank_missing = 0
    power_question_missing = 0
    april_rows = 0
    april_blank_missing = 0
    april_question_missing = 0
    april_points = []
    april_calendar = []
    april_last_ms = None
    source_bytes = 0
    probe = run["selection"]["pointProbe"]
    probe_ms = int(probe["timestampMs"])
    probe_raw = None
    probe_clock = None

    with source.open("rb") as stream:
        for line_no, raw_line in enumerate(stream, 1):
            digest.update(raw_line)
            source_bytes += len(raw_line)
            text = raw_line.decode("utf-8", errors="strict")
            if text.endswith("\n"):
                text = text[:-1]
            if text.endswith("\r"):
                text = text[:-1]
            if line_no == 1:
                if text != HEADER:
                    raise ValueError("unexpected UCI header")
                continue
            if not text:
                raise ValueError(f"line {line_no}: blank data row")
            fields = text.split(";")
            if len(fields) != 9:
                raise ValueError(f"line {line_no}: expected 9 fields, got {len(fields)}")
            clock, timestamp = parse_clock(fields[0], fields[1], line_no)
            rows += 1
            raw_power = fields[2].strip()
            missing = raw_power == "" or raw_power == "?"
            if missing:
                if raw_power == "?":
                    power_question_missing += 1
                else:
                    power_blank_missing += 1
            else:
                if not NUMBER.fullmatch(raw_power):
                    raise ValueError(f"line {line_no}: invalid Global_active_power")
                power = float(raw_power)
                if not math.isfinite(power):
                    raise ValueError(f"line {line_no}: non-finite Global_active_power")

            if clock.year == 2007 and clock.month == 4:
                expected_ms = wall_clock_ms(2007, 4, 1, 0, 0, 0) + april_rows * 60_000
                if timestamp != expected_ms:
                    raise ValueError(f"line {line_no}: April rows are not one-minute contiguous")
                april_rows += 1
                april_last_ms = timestamp
                april_calendar.append((timestamp, None if missing else power, raw_power, fields[0], fields[1]))
                if missing:
                    if raw_power == "?":
                        april_question_missing += 1
                    else:
                        april_blank_missing += 1
                else:
                    april_points.append((timestamp, power, raw_power, fields[0], fields[1]))
                if timestamp == probe_ms:
                    probe_raw = raw_power if not missing else None
                    probe_clock = f"{fields[0]} {fields[1]}"

    source_sha = digest.hexdigest()
    if source_sha != EXPECTED_SOURCE_SHA256:
        raise ValueError(f"source does not match pinned UCI text SHA-256: {source_sha}")
    if rows != EXPECTED_ROWS:
        raise ValueError(f"expected {EXPECTED_ROWS} source rows, got {rows}")
    if april_rows != EXPECTED_MONTH_ROWS:
        raise ValueError(f"expected {EXPECTED_MONTH_ROWS} April rows, got {april_rows}")
    if april_last_ms != wall_clock_ms(2007, 4, 30, 23, 59, 0):
        raise ValueError("April wall-clock endpoint mismatch")
    if source_bytes != run["source"]["bytes"] or source_sha != run["source"]["sha256"]:
        raise ValueError("independent full-source byte count/SHA-256 differs from importer")
    if rows != run["source"]["rows"]:
        raise ValueError("independent source row count differs from importer")
    if power_blank_missing != run["source"]["globalActivePowerMissing"]["blank"]:
        raise ValueError("global blank-missing count differs from importer")
    if power_question_missing != run["source"]["globalActivePowerMissing"]["questionMark"]:
        raise ValueError("global '?' missing count differs from importer")
    if april_rows != run["selection"]["rows"]:
        raise ValueError("April row count differs from importer")
    if len(april_points) != run["selection"]["encodedSamples"]:
        raise ValueError("April non-missing sample count differs from importer")
    if april_blank_missing != run["selection"]["missing"]["blank"]:
        raise ValueError("April blank-missing count differs from importer")
    if april_question_missing != run["selection"]["missing"]["questionMark"]:
        raise ValueError("April '?' missing count differs from importer")

    point = run["selection"]["pointProbe"]
    if probe_raw is None or probe_clock != f"{point['date']} {point['time']}" or probe_raw != point["sourceValue"]:
        raise ValueError("point probe does not identify the same raw source row")
    probe_bits = int.from_bytes(struct.pack(">d", float(probe_raw)), "big")
    if str(probe_bits) != point["bits"]:
        raise ValueError("point probe IEEE-754 bits differ from source conversion")
    if not any(ts == probe_ms and raw == probe_raw for ts, _, raw, _, _ in april_points):
        raise ValueError("point probe timestamp/value is absent from independent April scan")

    query_selection = run["selection"]["queryWindowSelection"]
    at_ms = int(query_selection["atMs"])
    start_ms = at_ms - 30 * 60 * 1000
    values = [value for timestamp, value, _, _, _ in april_points if start_ms < timestamp <= at_ms]
    if not values:
        raise ValueError("selected PromQL window unexpectedly contains no measured values")
    if len(values) >= 30 or query_selection["calendarRows"] != 30 or query_selection["missingRows"] != 30 - len(values):
        raise ValueError("selected query window must expose at least one missing measurement and one measured value")
    closed_candidates = sum(1 for timestamp, value, *_ in april_calendar if start_ms <= timestamp <= at_ms and value is not None)
    if closed_candidates != run["query"]["queries"]["count"]["samplesLoaded"]:
        raise ValueError("closed archive candidates differ from the selected range samples passed to the evaluator")
    expected = {
        "count": float(len(values)),
        "avg": math.fsum(values) / len(values),
        "min": min(values),
        "max": max(values),
    }
    for name, expected_value in expected.items():
        observed = run["query"]["queries"][name]
        if int(observed["atMs"]) != at_ms:
            raise ValueError(f"{name}: query evaluation timestamp differs")
        if int(observed["window"]["start"]) != start_ms or int(observed["window"]["end"]) != at_ms:
            raise ValueError(f"{name}: query planner window differs from 30m wall-clock range")
        if observed["archiveBytes"] != run["archive"]["bytes"]:
            raise ValueError(f"{name}: query archive byte total differs from archive manifest")
        if not (0 < observed["bytesRead"] < observed["archiveBytes"]):
            raise ValueError(f"{name}: range query did not read a bounded proper subset")
        if observed["samplesLoaded"] != closed_candidates:
            raise ValueError(f"{name}: closed-range archive candidate count differs")
        actual = float(observed["value"])
        if not math.isclose(actual, expected_value, rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError(f"{name}: MoonPromQL={actual!r}, independent Python={expected_value!r}")

    empty_selection = run["selection"]["allMissingWindow"]
    empty_at = int(empty_selection["atMs"])
    empty_start = empty_at - 30 * 60 * 1000
    empty_rows = [row for row in april_calendar if empty_start < row[0] <= empty_at]
    if len(empty_rows) != 30 or any(row[1] is not None for row in empty_rows):
        raise ValueError("independent source scan did not find 30 consecutive missing power rows")
    empty_candidates = sum(1 for row in april_calendar if empty_start <= row[0] <= empty_at and row[1] is not None)
    for name, observed in run["query"]["allMissingWindow"].items():
        if observed["resultKind"] != "instant" or observed["points"] != 0 or observed["samplesLoaded"] != empty_candidates or "value" in observed:
            raise ValueError(f"all-missing {name} query must return no point, not zero or NaN")
        if int(observed["atMs"]) != empty_at or int(observed["window"]["start"]) != empty_start or int(observed["window"]["end"]) != empty_at:
            raise ValueError(f"all-missing {name} query has the wrong 30-minute bounds")

    boundary_selection = run["selection"]["boundaryWindow"]
    boundary_at = int(boundary_selection["atMs"])
    boundary_start = boundary_at - 30 * 60 * 1000
    boundary_values = [value for timestamp, value, _, _, _ in april_points if boundary_start < timestamp <= boundary_at]
    boundary_by_timestamp = {row[0]: row for row in april_calendar}
    boundary_left = boundary_by_timestamp.get(boundary_start)
    boundary_right = boundary_by_timestamp.get(boundary_at)
    if len(boundary_values) == 0 or boundary_left is None or boundary_right is None or boundary_left[1] is None or boundary_right[1] is None:
        raise ValueError("boundary comparison requires measured samples exactly at both bounds")
    for name, row in (("left", boundary_left), ("right", boundary_right)):
        evidence = boundary_selection["boundaries"][name]
        expected_clock = f"{row[3]} {row[4]}"
        if evidence["timestampMs"] != str(row[0]) or evidence["sourceValue"] != row[2] or evidence["date"] + " " + evidence["time"] != expected_clock:
            raise ValueError(f"{name} boundary does not identify the same source row")
        if str(int.from_bytes(struct.pack(">d", row[1]), "big")) != evidence["bits"]:
            raise ValueError(f"{name} boundary IEEE-754 bits differ")
    boundary_closed = sum(1 for row in april_calendar if boundary_start <= row[0] <= boundary_at and row[1] is not None)
    boundary_open_right = sum(1 for row in april_calendar if boundary_start < row[0] < boundary_at and row[1] is not None)
    if boundary_closed != len(boundary_values) + 1 or boundary_open_right != len(boundary_values) - 1:
        raise ValueError("valid endpoints do not distinguish (start,end] from left-closed or right-open bounds")
    boundary_expected = {
        "count": float(len(boundary_values)),
        "avg": math.fsum(boundary_values) / len(boundary_values),
        "min": min(boundary_values),
        "max": max(boundary_values),
    }
    for name, expected_value in boundary_expected.items():
        observed = run["query"]["boundaryWindow"][name]
        if int(observed["atMs"]) != boundary_at or int(observed["window"]["start"]) != boundary_start or int(observed["window"]["end"]) != boundary_at:
            raise ValueError(f"boundary {name} query has incorrect range bounds")
        if observed["samplesLoaded"] != boundary_closed:
            raise ValueError(f"boundary {name} query loaded the wrong closed-bound archive candidates")
        if not math.isclose(float(observed["value"]), expected_value, rel_tol=1e-12, abs_tol=1e-12):
            raise ValueError(f"boundary {name}: MoonPromQL does not match independent (start,end] values")

    archive = run_dir / run["archive"]["file"]
    archive_hash = hashlib.sha256()
    archive_bytes = 0
    with archive.open("rb") as stream:
        for chunk in iter(lambda: stream.read(65_536), b""):
            archive_hash.update(chunk)
            archive_bytes += len(chunk)
    if archive_bytes != run["archive"]["bytes"] or archive_hash.hexdigest() != run["archive"]["sha256"]:
        raise ValueError("GOR2 artifact changed after the MoonBit-backed query")

    report = {
        "verified": True,
        "method": "Python standard library: independent byte-stream SHA-256, row/time parsing, raw decimal-to-binary64 point check, and (start,end] count/avg/min/max oracle",
        "source": {"rows": rows, "bytes": source_bytes, "sha256": source_sha, "expectedSha256": EXPECTED_SOURCE_SHA256, "matchesPinnedSource": source_sha == EXPECTED_SOURCE_SHA256, "globalActivePowerMissing": {"blank": power_blank_missing, "questionMark": power_question_missing}},
        "april2007": {"rows": april_rows, "samples": len(april_points), "missing": {"blank": april_blank_missing, "questionMark": april_question_missing}, "firstMs": str(april_points[0][0]), "lastMs": str(april_last_ms)},
        "pointProbe": {"date": point["date"], "time": point["time"], "timestampMs": str(probe_ms), "sourceValue": probe_raw, "ieee754Bits": str(probe_bits)},
        "window": {"date": query_selection["date"], "time": query_selection["time"], "startExclusiveMs": str(start_ms), "endInclusiveMs": str(at_ms), "calendarRows": query_selection["calendarRows"], "missingRows": query_selection["missingRows"], "measuredSamples": len(values), "closedBoundArchiveCandidates": closed_candidates, "expected": expected},
        "boundaryRangeCheck": {"date": boundary_selection["date"], "time": boundary_selection["time"], "startExclusiveMs": str(boundary_start), "endInclusiveMs": str(boundary_at), "leftExcluded": {"date": boundary_left[3], "time": boundary_left[4], "value": boundary_left[2], "bits": boundary_selection["boundaries"]["left"]["bits"]}, "rightIncluded": {"date": boundary_right[3], "time": boundary_right[4], "value": boundary_right[2], "bits": boundary_selection["boundaries"]["right"]["bits"]}, "measuredSamplesInOpenLeftClosedRight": len(boundary_values), "counterfactualCounts": {"leftClosed": boundary_closed, "rightOpen": boundary_open_right}, "expected": boundary_expected},
        "allMissingWindow": {"date": empty_selection["date"], "time": empty_selection["time"], "startExclusiveMs": str(empty_start), "endInclusiveMs": str(empty_at), "calendarRows": len(empty_rows), "measuredSamplesInOpenLeftClosedRight": 0, "closedBoundArchiveCandidates": empty_candidates, "countAndAvgQueriesReturnNoPoint": True},
        "comparedQueries": {name: {"moonpromql": run["query"]["queries"][name]["value"], "python": value, "bytesRead": run["query"]["queries"][name]["bytesRead"], "archiveBytes": run["query"]["queries"][name]["archiveBytes"], "samplesPassedToEvaluator": run["query"]["queries"][name]["samplesLoaded"]} for name, value in expected.items()},
        "boundaryQueries": {name: {"moonpromql": run["query"]["boundaryWindow"][name]["value"], "python": value, "closedBoundArchiveCandidates": run["query"]["boundaryWindow"][name]["samplesLoaded"]} for name, value in boundary_expected.items()},
        "archive": {"bytes": archive_bytes, "sha256": archive_hash.hexdigest()},
    }
    with output_path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(report, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
