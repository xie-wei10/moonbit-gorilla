# 与现有生态的衔接

2026-09-23先检索再实现。选择 [Santa968/MoonPromQL](https://github.com/Santa968/MoonPromQL)，直接使用官方Mooncakes `Santa968/moonpromql@0.1.0`。registry归档校验值 `4c6386fb27ef8b371775691fe16faa4af277baa8cf2cd44251aa0c5b15fa7a67`；实际读取下载包 model/ast/parser/eval API和selector实现后接入，未修改上游。

| 已有部分 | 复用方式 | 当前新增 |
|---|---|---|
| MoonPromQL parser/AST | 直接parse获取Expr/Selector | 遍历AST求所需时间窗口并集，保留offset/@，用索引读取数据 |
| MoonPromQL model | 实际创建LabelSet、Series、Sample | 原始UInt64浮点位模式和Int64时间戳的有边界转换 |
| MoonPromQL eval | 原样调用evaluate/EvalContext | 给已有求值器供应从压缩文件读取的样本 |
| Gorilla/XOR、GOR2 | 沿用已有压缩、索引与CRC | Node queryArchives将计划、文件读取、转换及上游求值串起来 |

该上游面向内存数据，不提供完整TSDB。GOR2也不是Prometheus磁盘格式或远程存储协议；本版只建立显式文件集到内存查询的桥梁。不实现或宣称实现自有PromQL新算法。

## 时间范围与数据语义

QueryPlan保存私有上游AST及求值时间；read_window返回所有selector窗口的保守闭区间并集。range取[终点-range,终点]供读取，上游再执行自己的左开右闭规则；instant包含固定5分钟回看。终点按固定上游版本的 `at_ms.unwrap_or(eval_time)-offset_ms` 计算。无selector的标量表达式不打开文件，也不代表对文件完成了校验。

上游0.1.0的 @ 使用毫秒；Prometheus @ 通常使用秒。这是上游兼容性差异，本适配不偷偷改写。range/offset/@若产生小数毫秒或越过±(2^53-1)则拒绝。查询长度4096、计划深度64/节点1024；上游解析错误原样失败。没有标签下推；跨不同时段selector的并集可能多读中间区间。

series()要求样本严格递增；同时间点不自动合并。NaN、无穷、stale标记拒绝，原归档仍保留这些位模式。Node入口拒绝重复标签和重复metric+labels序列身份，防止上游的确定性合并掩盖输入错误。数据时间单位必须由调用者声明为毫秒，归档本身不携带该单位。

Node queryArchives保证读取完整计划窗口，并在超出合计样本上限时关闭文件并报错。直接使用MoonBit QueryPlan.evaluate的调用者需自行提供完整相关序列及窗口，先用series()完成转换。不存在自动发现未传入序列或检查采集缺口的承诺。

## 实跑与边界

1. 采集当前Node示例进程RSS/heap，写入真实文件、原bits精确读回、上游avg_over_time与未压缩输入对比。指标不是客户数据。
2. 4096个原创确定性样本，用5个范围/offset/@/聚合表达式对照全量输入；查询语义在两侧都由同一上游提供，验证的是归档/剪裁不改结果，不是独立Prometheus语义认证。
3. 坏块被选中则失败；坏块位于窗口外时默认不检查，verifyAll可发现。资源上限、非法标签、NaN、时间精度、取消与句柄释放均检查。

上游还存在counter外推模型、正则、histogram、subquery、staleness等限制；本版继承其支持范围，不宣称完整PromQL。原Prometheus XOR参考检查只证明相应chunk互通，不证明TSDB兼容。既有算法不作原创算法申报，未联系上游或取得背书，无真实采用方证明。
