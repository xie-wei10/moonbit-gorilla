# Gorilla 压缩归档与 MoonPromQL 查询数据源 · 复审稿

本项目仓库：https://github.com/xie-wei10/moonbit-gorilla
模块/本地版本：`xie-wei10/gorilla` / `0.6.0`；交付许可证 MIT AND Apache-2.0。
本地完成，未推送/发布/提交表单。针对“生态衔接与实际场景不足”补充如下。

## 已有生态与新增连接
Gorilla是既有算法。现有 [MoonPromQL](https://github.com/Santa968/MoonPromQL) 提供内存时序查询，本项目不重复实现其查询语言。
直接依赖 Santa968/moonpromql@0.1.0，复用 parser/AST/model/eval；新增公开 /moonpromql 适配和真实文件 queryArchives 工作流。
按上游AST计算range、offset、@与瞬时lookback所需窗口，使用GOR2索引读取相关块，校验后转换为上游Series并求值。
MoonBit负责压缩、CRC、索引与适配；Node负责文件和样例指标采集。不是完整Prometheus TSDB或MoonBit原生文件I/O。

## 具体场景与复现
面向单机/边缘任务的指标快照与离线诊断：把已有指标归档，再查询指定时段，避免把整份样本全部送入内存求值。
`moon build --target js` → `node tools/refresh-engines.mjs` → `node examples/run-metrics-query.mjs`。
实际采集本例进程RSS/heap共48样本，写入GOR2、按bits精确读回，上游avg_over_time结果与未压缩同输入一致；保留文件、标签清单与报告。
这是可运行场景，不是客户采用证明；尚无确认使用方。

新增公开Prometheus导出夹具入口：`node examples/run-prometheus-dump.mjs NEW_DIRECTORY`。原文件15点/3序列，纯MoonBit校验标签/时间序并导入，GOR2位模式精确读回；Python独立核对15位值和窗口均值2.5。新增入口明确拒绝非有限/重复/乱序/越界及资源超限，只覆盖有限dump文本，不是全量OpenMetrics。参见PUBLIC-PROMETHEUS.md。

## 验证与限制
新测试含3组MoonBit适配检查、11组文件/查询流程；4096样本的固定用例中选定查询加载12样本、读4858/16593归档字节，并与全量输入结果相同。
这不是通用性能结论。查询子集由上游决定：@采用上游毫秒语义，非有限值/stale及不精确时间戳拒绝；标签/序列清单需应用提供完整。
GOR2为自有容器，不等于Prometheus TSDB；默认只校验选中块，verifyAll可全检。无抓取/remote read-write/生产部署或上游背书声明。
完整接口、实跑日志和剩余边界见 UPSTREAM-RELATION.md、TESTING.md；请求依据实际衔接补充重新审核。
