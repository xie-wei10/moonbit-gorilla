# Gorilla 压缩归档与 MoonPromQL 查询数据源

本项目仓库：https://github.com/xie-wei10/moonbit-gorilla

模块 `xie-wei10/gorilla`，本地版本 **0.7.0**，直接依赖 `Santa968/moonpromql@0.1.0`。本项目代码 MIT，上游 Apache-2.0；包含上游的交付标注 MIT AND Apache-2.0。仅本地，未推送或发布。

本版补充初审要求的生态衔接与使用流程：已有 [MoonPromQL](https://github.com/Santa968/MoonPromQL) 提供内存时序查询，本项目提供压缩归档、索引范围读取和完整性检查。新增 `/moonpromql` 包把读回的样本送入上游模型与查询引擎，复用它的解析器、AST和求值器，不重写查询语言。

0.6.0 新增[公开Prometheus输入工作流](PUBLIC-PROMETHEUS.md)：纯MoonBit有限dump导入器，实际GOR2文件，官方15点/3序列夹具与Python位模式/窗口均值对照。不是生产监控采用证据。

0.7.0 新增[UCI家庭用电完整月消费者](REAL-HOUSEHOLD.md)：完整流读UCI原始文件并核对行数/SHA-256，只将2007年4月的Global_active_power写入GOR2；离线30分钟PromQL的count/avg/min/max由Python标准库从原始记录独立对照。缺失值保留为时间洞，日期时间只编码为无时区的wall-clock坐标。证据还核对有效的左右端点及全缺失查询返回空向量（没有变成0/NaN）。实测数据与许可证归属见 [evidence/real-household-20260927](evidence/real-household-20260927/LOCAL-CHECKS.json)；不代表47个月数据验证、TSDB替代或实际部署。

## 可复现的落地流程

适用于保存单机/边缘任务的指标快照，事后读取某个时段进行分析。下例采集的是**本示例进程自己的内存指标**，不是团队实际客户或生产部署。

```sh
moon build --target js
node tools/refresh-engines.mjs
node examples/run-metrics-query.mjs
```

采集 RSS/heap 两个指标共48个样本 → 分别写入带校验的 GOR2 文件 → 位模式精确读回 → 上游执行 `avg_over_time(process_memory_bytes[1s])`。自动断言压缩输入与未压缩输入查询一致。运行后打印新的临时目录，其中保存两份归档、指标/标签/时间单位清单及 report.json；数字随本机运行而变，不把它们作为固定性能成绩。

已有数据可使用 `tools/query-archive.mjs` 的 `queryArchives({series, query, at})`；每条 series 显式提供 `file`、`metric` 和 `[标签名,标签值]` 数组，`at` 为整数毫秒。示例与接口边界见 [USE-CASE.md](USE-CASE.md) 和 [生态关系](UPSTREAM-RELATION.md)。

## 读取正确的数据

查询计划由**上游 AST**产生，计算所有 selector 所需时间窗口的保守并集，包含范围、offset、上游的毫秒制 @ 和瞬时查询5分钟回看。随后通过已有 ArchiveFile 索引只读相关块，再调用上游 evaluator。不是按用户指定的随意截断窗口得出看似成功的结果。暂未做标签下推，调用者必须提供相关的完整序列集合。

`node tools/test-query-archive.mjs` 的原创建模输入共4096样本；选定5分钟查询加载12个样本（磁盘仍按块解码），读4858字节/归档共16593字节，与全量输入的上游结果一致。11组流程检查包括 offset/@、左开右闭区间、损坏块、资源上限及非有限值拒绝。这是固定样例的 I/O 结果，不声称通用性能提升。

## 分工与明确限制

- MoonBit：Gorilla/XOR、CRC、GOR2块索引、上游AST读取范围计划和数据模型转换；Node：文件与本例指标采集；MoonPromQL：PromQL子集的解析、函数和求值。
- 查询适配要求严格递增、可用Double精确表示的整数毫秒时间戳；拒绝 NaN、无穷和 stale markers，**不静默删除**。原压缩库仍能保存负零及NaN payload，不把数学查询结果当作原位模式存档。
- 默认仅校验读到的块；`verifyAll:true` 会额外读并检查全部块。CRC不是密码学认证。每次最多64序列、合计100000个加载样本；超限报错，不返回部分查询结果。
- GOR2不是完整Prometheus TSDB格式；无抓取服务、remote read/write、指标自动发现、告警规则、实时持久化服务或生产部署证明。上游查询子集与Prometheus存在语义差异，详见关系说明。

[验证](TESTING.md)、[申报书](PROPOSAL.md)、[复核说明](REVIEW-RESPONSE.md)、[查重](DUPLICATION.md)、[许可证](THIRD-PARTY-NOTICES.md)。Gorilla算法是既有工作；本版贡献范围是压缩归档与已有生态查询能力的实际连接。对接团队需同步公开代码和表单，再请求复审；不保证通过。

CI固定的编译器与标准库版本见 [TOOLCHAIN.md](TOOLCHAIN.md)；升级时需同时核对生成产物。

## 本地验收与公开交付（2026-09-28）

核心实现使用 MoonBit；[固定编译器](.moonbit-version)为 `moonc 0.10.14+7d59c7ec9`。先按本文安装宿主依赖、运行 `moon update`，再从仓库根目录执行以下与 [CI](.github/workflows/ci.yml) 对齐的检查；可运行任务和适用边界见本文前面的示例与说明。

```sh
moon check --deny-warn
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon build --target js --deny-warn
moon package
```

本地核验：JS/Wasm-GC 测试、指标查询、归档、Prometheus 数据交换和 XOR/GOR1 参考检查通过。 `moon package` 已完成离线打包预检，它不等于已发布到 Mooncakes。

公开交付（2026-09-28 核对）：当日 [https://github.com/xie-wei10/moonbit-gorilla](https://github.com/xie-wei10/moonbit-gorilla) 可匿名读取 Git HEAD，Mooncakes 在线版本为 `0.4.0`；此处源码版本 `0.7.0` 仍需由团队同步到公开仓库，检查新提交的 GitHub Actions，再由对应账号发布 Mooncakes 新版。相关远端 CI 与赛事结果仍需以实际记录核对。项目许可见 [LICENSE](LICENSE)；如使用第三方材料，其来源和许可见仓内相应说明。
