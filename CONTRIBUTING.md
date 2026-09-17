# Contributing locally

This is an independent repository. Do not import or reference sibling repositories. Run `./verify.ps1 -MoonPath /absolute/path/to/moon` before committing. Add public-API regressions for behavioral changes; document unsupported syntax and observable errors. `moon fmt` and `moon info` must be idempotent. Generated JS must be rebuilt with the library.

Use `node tools/cli.mjs --help` for the original file/stdin interface, `node tools/archive-cli.mjs --help` for indexed streaming files, and `node tools/robustness.mjs` for bounded malformed inputs. The original `tools/benchmark.mjs` measures only the JS example. See TESTING.md for the separate real-data Prometheus comparison, its pinned inputs, runtime differences, and limits.
