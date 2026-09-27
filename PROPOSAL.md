# Gorilla GOR2 indexed archive and MoonPromQL adapter

Repository: https://github.com/xie-wei10/moonbit-gorilla  
Module: `xie-wei10/gorilla` 0.7.0 · MIT; upstream dependency `Santa968/moonpromql@0.1.0` · Apache-2.0.  
Status: revised local materials only; no public update or acceptance is claimed.

## Contribution

Gorilla/XOR compression is prior work. This project contributes a checksummed, indexed GOR2 archive with bounded range reads and an adapter that plans the required read window from the pinned MoonPromQL AST, then passes validated samples to that upstream evaluator. It does not reimplement PromQL.

## Reproducible use

The UCI household-power consumer streams and hashes the complete public source, validates its documented row count, writes one complete month of `Global_active_power` to GOR2, and runs offline 30-minute PromQL statistics. A Python standard-library oracle independently checks the source, missing-value gaps, one point's timestamp/bits, and count/average/minimum/maximum. See [REAL-HOUSEHOLD.md](REAL-HOUSEHOLD.md) and [the checked-in evidence](evidence/real-household-20260927/LOCAL-CHECKS.json).

The run used all 2,075,259 input rows but encoded only April 2007: 43,200 wall-clock rows, 39,477 measured values, and 3,723 explicit missing measurements. Python and MoonPromQL agreed on count/average/minimum/maximum, verified valid left/right endpoint samples against `(start,end]`, and confirmed a fully missing window returns no point. One selected query read 6,316 of 233,699 archive bytes. The source has no declared timezone, so timestamps are labeled timezone-free wall-clock coordinates.

## Boundaries

This evidence covers one month and one source column, not all 47 months or every dataset field. GOR2 is not Prometheus TSDB. There is no scrape service, remote read/write, alerting, deployment, or user-adoption evidence. The repository's finite promtool-dump consumer remains documented separately in [PUBLIC-PROMETHEUS.md](PUBLIC-PROMETHEUS.md). No contest decision, public submission, or acceptance is established by this local work.
