# 验证与复现

默认验证完全重放已保存参考向量，不需要在线 Go 依赖或观测数据：

```powershell
./verify.ps1 -MoonPath C:/path/to/moon/bin/moon.exe
```

包含 fmt/info、deny-warn、显式 JS/Wasm-GC（本次各 18 组）、生成 38 个官方黄金字节向量、重建引擎、旧入口、新文件/CLI、277 个 XOR、144 个 GOR1、5 个 GOR2 容器对照的离线重放，以及现有 307 条异常输入和样例计时。完整源/API/引擎指纹见 `evidence/indexed-upgrade.json`；远端 CI 尚未运行。

## 在线独立参考

`tools/oracle` 是原创 Go 可执行适配器，仅调用固定官方 `github.com/prometheus/prometheus v0.314.0` 的 `chunkenc`；go.mod/go.sum 固定依赖，不复制或修改官方 codec。需要 Go 1.25.8 或更高：

```powershell
Push-Location tools/oracle
 go build -trimpath -o gorilla-oracle.exe .
Pop-Location
$env:GORILLA_ORACLE=(Resolve-Path tools/oracle/gorilla-oracle.exe).Path
./verify.ps1 -MoonPath C:/path/to/moon/bin/moon.exe -WithReference
```

Unix 使用适合平台的输出文件名和环境变量。Windows 本次参考以 WSL Go 1.26.0 交叉构建为原生 Windows 可执行文件；实际编码/解码与 MoonBit JS 都在同一 Windows 主机运行。每条请求采用十进制 timestamp/bits，保持精确原始位模式；JSON 之外才执行官方浮点位转换，包含 signaling NaN 检查。

- `test-xor-reference.mjs`：277 个本地原创案例，涵盖 signed 时间边界/回绕、所有窗口位置、delta 分组边界、NaN/无穷/正负零、随机不规则输入、65535 条容量。检查完全相同的编码字节、官方自解码、双方交叉解码。
- `gor1_oracle.py` / `test-gor1-reference.mjs`：144 个旧格式案例，Python 任意精度整数和位字符串独立表达 FORMAT.md，区别于 MoonBit 打包字节状态机；只证明本项目 GOR1 规格，不声称上游兼容。
- `archive_oracle.py` / `test-archive.mjs`：Python struct/zlib 独立构造和校验索引/CRC，官方 Go 处理负载。共 10 组检查，其中一组包含 5 个容器全字节一致及双向解码案例；其余覆盖 10 万条流式输入/解码、索引读取、区间外损坏、取消、防覆盖、资源释放和实际文件/CLI。
- `archive_test.mbt` 与 `xor_vectors_test.mbt`：同一公共 API 在两个后端运行，覆盖逐字节/多种分片、每个截断位置、错误后状态、空文件、顺序拒绝、重复时间、CRC 标准向量及官方字节。

参考报表区分 `live` 与 `saved`，默认重放不会冒充新运行上游库。合法上游 XOR 位流一致；默认严格尾部检查更严格，`strict=false` 按参考样本数停止。上游所有损坏输入的错误文本/接受规则未承诺一致。

## 实际数据与性能

```powershell
python tools/prepare-data.py C:/testdata/gorilla --download
$env:GORILLA_DATA_DIR='C:/testdata/gorilla'
./verify.ps1 -MoonPath C:/path/to/moon/bin/moon.exe -WithReference -WithBenchmark
```

数据只写到指定本地目录，不随库打包。来源：

- [NOAA Mauna Loa 日均 CO2](https://gml.noaa.gov/ccgg/trends/data.html)，本次 15983 条。鸣谢 NOAA GML / Xin Lan、Scripps / Ralph Keeling；近期数据可能修订，下载内容的 SHA256 单独记录。
- [USGS Earthquake Catalog](https://earthquake.usgs.gov/fdsnws/event/1/)，2025-01-01 到 2025-02-01、震级至少 2.5、按时间排序，2258 个事件，分别压缩震级和深度。
- 固定生成的规则计数器、周期信号、均匀噪声，各 20000 条；明确标为合成数据。

所有观测值转为 float64 原始位模式，时间转 UTC 毫秒，不做降采样/有损近似；缺失值处理记录在报告。`compression-reference.json` 记录编码字节、原始 16 字节/样本基线、每样本字节数及精确参考比较。

计时排除 JSON/十进制字符串转换与子进程 I/O：3 次预热，9 次测量取中位数；MoonBit JS 单次运行，原生 Go 每次取 32 次均值，避免 Windows 短计时分辨率导致零结果。编码创建字节、解码创建类型化样本数组；两者运行时不同。`compression-baseline.json` 为按位读写优化前的同一批数据，最终报告为按字节处理后的结果。JS 仍明显慢于原生 Go；没有性能追平、长期负载或内存优劣结论。

CRC 和严格语义校验不是认证；query 跳过块不验证其负载，这一行为有显式错误路径测试，不能把局部读取说成完整文件验证。
