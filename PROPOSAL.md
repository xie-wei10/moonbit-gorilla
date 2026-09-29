# Gorilla GOR2：索引化时序归档与 MoonPromQL 查询适配

项目仓库：https://github.com/xie-wei10/moonbit-gorilla。模块 `xie-wei10/gorilla@0.7.0`；MIT AND Apache-2.0。申请范围是 MoonBit 时序归档与现有查询引擎之间的可复用数据层。

## 场景与核心能力

离线监测数据需要按时间范围反复读取，而缺测不能被填成零、窗口端点也不能多算或少算。本库提供 Gorilla/XOR 编解码、带校验和索引的 GOR2 归档、有界时间读取，并从固定 MoonPromQL AST 规划读取窗口，把结果交给其 evaluator。调用方能把文件存储与查询组合起来；不另造 PromQL 执行器。

## 独立贡献与现有生态

Gorilla 压缩算法、Prometheus 时序系统和列式存储均有成熟实现。项目实际复用 [Santa968/MoonPromQL](https://github.com/Santa968/MoonPromQL)，其查询语义归于上游；[mizchi/parquet](https://github.com/mizchi/parquet) 是 MoonBit 另一种文件交换选择。本项目的交付价值是同一 MoonBit 核心中的有界编解码、索引读取及查询接入，不主张算法首创、TSDB 兼容或性能优胜。

## 公开数据任务

使用 UCI Individual Household Electric Power Consumption（Hebrail 与 Berard，DOI 10.24432/C58K54，CC BY 4.0）。导入器流式校验完整原文 2,075,259 行及固定 SHA-256，仅编码 2007 年 4 月 `Global_active_power` 一列：43,200 个分钟行中保留 39,477 个测量值，将 3,723 个缺失项保留为时间洞。数据未声明时区，数值时间轴不冒称 UTC。

按 [REAL-HOUSEHOLD](REAL-HOUSEHOLD.md) 运行文件到查询的完整流程。30 分钟 `(start,end]` 窗口的 count/avg/min/max 与独立 Python 原文重算一致；另以端点均有值的窗口证明左端排除、右端纳入，以全缺测窗口证明返回空向量。选定窗口读取 6,316 字节，归档共 233,699 字节；这是一次场景记录，不是通用性能结论。

## 可靠性与交付边界

AI 生成的统计代码仍必须遵守测量身份、缺失值和时间窗契约；库把这些约束与独立参考结果保留为可复核接口。公开记录说明具体用途，不代表 UCI 或其他使用方采用本库。当前只验证上述一月单列，不覆盖整个数据集、持续写入、抓取服务、告警或远程读写。交付包含 MoonBit 库、Node 文件消费者、可运行查询、数据署名和分层证据。

**公开状态（2026-09-29 核对）**：GitHub [公开仓库](https://github.com/xie-wei10/moonbit-gorilla)、[Mooncakes 0.7.0](https://mooncakes.io/docs/xie-wei10/gorilla@0.7.0) 已可访问；[CI 成功记录](https://github.com/xie-wei10/moonbit-gorilla/actions/runs/36435951979) 对应 `1e63af377d10`。本次材料更新尚未推送；该远端 CI 对应所列公开提交。报名表一致性及赛事审核结果尚未核实。
