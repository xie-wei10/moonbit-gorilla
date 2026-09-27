# Gorilla GOR2 索引归档与 MoonPromQL 查询适配
项目：`xie-wei10/gorilla` 0.7.0；仓库：[moonbit-gorilla](https://github.com/xie-wei10/moonbit-gorilla)。
状态：仅本地修订材料；未声称公开更新、参赛通过或获奖。

## 项目贡献
Gorilla/XOR 压缩是既有工作；本项目提供校验和索引化 GOR2 归档、有界时间范围读取，并从固定 MoonPromQL AST 规划读取窗口后交给上游 evaluator，不重写 PromQL。

## 可复现消费者
真实数据取自 UCI [Individual Household Electric Power Consumption](https://archive.ics.uci.edu/dataset/235/individual%2Bhousehold%2Belectric%2Bpower%2Bconsumption)，Hebrail 与 Berard (2006)，DOI `10.24432/C58K54`，数据许可 CC BY 4.0。

导入器流式扫描全部 2,075,259 行、132,960,755 字节，并固定校验原始文本 SHA-256 `4259c9d7ece5dbee9ab8d53682baac68d791c864f0f64a52b4043cb3b90894b7`；原始 ZIP/TXT 不随包分发。

只编码 2007 年 4 月完整单列 `Global_active_power`（kW）：43,200 个分钟墙钟行、39,477 个实测值、3,723 个缺失值。`?`/空值作为时间洞，不填零。
数据未声明时区；时间戳仅是无时区的 wall-clock 坐标，不表示 UTC。

离线 30 分钟 `(start,end]` 窗口由 MoonPromQL 计算 count/avg/min/max，并与独立 Python 标准库从原始十进制值重算的结果一致：count 29、avg 1.1613103448275863、min 0.488、max 1.478。

单独验证左右端点均有值：左端排除、右端纳入，结果 count 30；左闭会为 31，右开会为 29。全缺失窗口的 count/avg 均返回空向量，不报告零或 NaN。

该混合窗口每次索引读取 6,316 字节，归档总计 233,699 字节；这是 `ArchiveFile.bytesRead` 的单次场景观测，不是基准测试或性能优越性结论。

## 许可与边界
项目代码与随附 MoonPromQL 编译件按 `moon.mod` 声明 MIT AND Apache-2.0；派生 GOR2 数据文件按 CC BY 4.0 署名，转换范围及链接见 [第三方说明](THIRD-PARTY-NOTICES.md)。

复现步骤、缺失值/时间策略及完整测量见 [REAL-HOUSEHOLD.md](REAL-HOUSEHOLD.md) 和 [本地回执](evidence/real-household-20260927/LOCAL-CHECKS.json)。
本证据仅覆盖一个月、一列，不代表验证了全部 47 个月或 9 个字段。GOR2 不是 Prometheus TSDB。

不包含抓取服务、远程读写、告警、部署、外部采用证明；赛事是否接收、公开提交或批准仍未确定。
