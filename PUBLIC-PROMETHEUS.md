# 从 Prometheus 导出样本到 GOR2，再供 MoonPromQL 查询

公开输入固定为 Prometheus commit `ea954809ceafceb53ecfa295ab0947753929de9e` 的 `cmd/promtool/testdata/dump-test-1.prom`，15点、3序列、毫秒时间。原文件、Apache-2.0许可、NOTICE及SHA-256保存在 `examples/prometheus`。这是上游测试夹具，不是生产监控数据；旧版自己的48点进程采样是另一种证据，两者不混称客户落地。

```sh
moon build --target js
node tools/refresh-engines.mjs
node examples/run-prometheus-dump.mjs NEW_DIRECTORY
python tools/verify-prometheus-dump.py
```

公开 `/moonpromql` 包新增 `parse_promtool_dump`：有限十进制值、带 `__name__` 的等号标签集合、显式整数毫秒。标签字符串和转义由现有 MoonPromQL parser 解析，项目自己负责系列身份、时间序、位模式与限额。供其他MoonBit包调用，不要求通过Node命令使用。

`tools/import-promtool.mjs` 的 `importPromtoolDump(input, output)` 只是文件宿主：严格UTF8、最多4MB文件，调用MoonBit后写多个GOR2，最后才写 `manifest.json` 的 `complete:true`。失败可能留下不完整目录，消费者必须要求完成清单；没有跨目录事务保证。默认不覆盖已有目录/归档。返回的 `series` 可交给已有 `queryArchives`；源哈希和标签清单与文件一起保存。

纯核心限额为4M UTF16单位、单行16384单位、最多64序列和总计100000样本；每序列时间严格递增。拒绝重复/乱序时间、超Double精确整数范围、非有限值/stale、histogram、重复/正则标签或字段缺失。不声称兼容全部 Prometheus/OpenMetrics输入、注释/元数据或原生TSDB块。格式没有计数/footer，不能发现恰好在完整行边界丢失后缀，须用完整文件哈希/来源校验。

查询 `avg_over_time(heavy_metric{foo="bar"}[2m])`，at=180000ms：计划保守读 `[60000,180000]`，上游求值按 `(60000,180000]` 选值3和2，结果2.5。三序列读入9点，标签筛选留给上游；全部15点写入/读取的位模式保持。独立Python从原始文本按IEEE754打包并直接算有限窗口均值，验证存储和边界连接。tiny样例不用于宣称压缩率或通用IO性能优势。

本项目核心是可消费的归档、CRC/索引、有界窗口供给和输入完整性契约；Gorilla算法和PromQL查询能力分别归原始工作及MoonPromQL。没有抓取服务、remote read/write、完整TSDB或生产采用证明。
