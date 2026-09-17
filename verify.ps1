param([string]$MoonPath, [switch]$WithReference, [switch]$WithBenchmark)
$ErrorActionPreference='Stop'
if (-not $MoonPath) {
  $available=Get-Command moon -ErrorAction SilentlyContinue
  if ($available) { $MoonPath=$available.Source }
  else { throw 'Install MoonBit or pass -MoonPath with the absolute moon.exe path.' }
}
$env:MOON_HOME=Split-Path (Split-Path $MoonPath -Parent) -Parent
$env:PATH="$(Split-Path $MoonPath -Parent);$env:PATH"
Push-Location $PSScriptRoot
try {
  node tools/generate-xor-tests.mjs
  if ($LASTEXITCODE -ne 0) {throw 'reference vector generation failed'}
  & $MoonPath fmt
  if ($LASTEXITCODE -ne 0) {throw 'format failed'}
  & $MoonPath info
  if ($LASTEXITCODE -ne 0) {throw 'API generation failed'}
  & $MoonPath check --deny-warn
  if ($LASTEXITCODE -ne 0) {throw 'check failed'}
  & $MoonPath test --target wasm-gc --deny-warn
  if ($LASTEXITCODE -ne 0) {throw 'tests failed'}
  & $MoonPath test --target js --deny-warn
  if ($LASTEXITCODE -ne 0) {throw 'JS tests failed'}
  & $MoonPath build --target js --deny-warn
  if ($LASTEXITCODE -ne 0) {throw 'build failed'}
  & $MoonPath run cmd/main
  if ($LASTEXITCODE -ne 0) {throw 'example failed'}
  $engine=Get-ChildItem '_build/js' -Recurse -File | Where-Object { $_.Name -in @('main.js','web.js') -and $_.FullName -match '[\\/]cmd[\\/]web[\\/]' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $engine) {throw 'Missing browser engine'}
  Copy-Item -LiteralPath $engine.FullName -Destination 'web/engine.mjs' -Force
  node tools/test-demo.mjs
  if ($LASTEXITCODE -ne 0) {throw 'browser engine test failed'}
  node tools/test-blocks.mjs
  if ($LASTEXITCODE -ne 0) {throw 'file codec tests failed'}
  if ($WithReference) {
    node tools/test-xor-reference.mjs
    if ($LASTEXITCODE -ne 0) {throw 'Prometheus reference comparison failed'}
    node tools/test-gor1-reference.mjs
    if ($LASTEXITCODE -ne 0) {throw 'GOR1 reference comparison failed'}
    node tools/test-archive.mjs
    if ($LASTEXITCODE -ne 0) {throw 'archive reference/integration failed'}
  } else {
    node tools/test-xor-reference.mjs --golden
    if ($LASTEXITCODE -ne 0) {throw 'Prometheus reference replay failed'}
    node tools/test-gor1-reference.mjs --golden
    if ($LASTEXITCODE -ne 0) {throw 'GOR1 reference replay failed'}
    node tools/test-archive.mjs --golden
    if ($LASTEXITCODE -ne 0) {throw 'archive replay/integration failed'}
  }
  if ($WithBenchmark) {
    node tools/benchmark-reference.mjs
    if ($LASTEXITCODE -ne 0) {throw 'real-data reference benchmark failed'}
  }
  node tools/test-cli.mjs
  if ($LASTEXITCODE -ne 0) {throw 'CLI test failed'}
  node tools/robustness.mjs
  if ($LASTEXITCODE -ne 0) {throw 'robustness failed'}
  node tools/benchmark.mjs
  if ($LASTEXITCODE -ne 0) {throw 'benchmark failed'}
} finally {Pop-Location}
