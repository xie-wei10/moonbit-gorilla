# 查重与生态定位 · 2026-09-23

Gorilla/XOR是既有压缩算法，不申报算法首创，也不以检索零命中证明生态空白。此前来源与范围记录保留于 [旧记录](DUPLICATION-BEFORE-MOONPROMQL.md)。

本次先检索MoonBit时序/指标/查询项目，核对 [MoonPromQL](https://github.com/Santa968/MoonPromQL) 后选择直接复用其已发布0.1.0。其查询语言与内存模型已经存在，本项目只补压缩归档数据读取和类型/范围适配。相关边界与真实依赖见 [UPSTREAM-RELATION.md](UPSTREAM-RELATION.md)。

另检索到 [moonbit-community/opentelemetry](https://github.com/moonbit-community/opentelemetry.mbt) 和官方registry中的 guiqi695/moon-prometheus-sdk；本版**没有**接入它们，不把搜索结果列成完成的生态集成。对指标采集协议和完整存储服务有需求应另评估已有项目，不把本例Node memoryUsage采集当作OTel exporter。

[Prometheus chunkenc](https://github.com/prometheus/prometheus/tree/v3.14.0/tsdb/chunkenc) 为历史XOR互通来源；GOR2不是其TSDB容器。检索不覆盖私有仓库、全部报名或未公开分支，也不替评委认定创新性。
