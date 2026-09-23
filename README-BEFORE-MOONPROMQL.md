# 保留浮点位模式的时序压缩与范围归档

**本项目仓库：[https://github.com/xie-wei10/moonbit-gorilla](https://github.com/xie-wei10/moonbit-gorilla)**

模块 `xie-wei10/gorilla`，本地版本 **0.4.0**，MIT。当前评审状态：**保留候选**。本文件是当前入口，旧轮次说明与详细用法保存在 [历史/完整使用说明](README-BEFORE-VALUE-REWORK.md)。

## 解决什么任务

将时间戳/原始浮点位模式归档，并按时间索引读取小范围、定位坏块；数据仍可按 Prometheus XOR chunk 交换。

需要原始浮点位模式、块索引和坏块定位时评估；如果只是 JSON 导出，无须引入该自有容器。

## 直接复现

安装 MoonBit 和 Node.js 24，在本仓库根目录运行：

```sh
moon build --target js
node -e "require('node:fs').copyFileSync('_build/js/debug/build/cmd/web/web.js','web/engine.mjs')"
node examples/run-use-case.mjs
```

流程：**保留特殊浮点位模式的区间归档**。运行器创建新的系统临时目录，保留每一步的 stdout/stderr、产物及 `report.json`，打印实际目录；重复运行不会覆盖之前产物。它只执行仓库内的本地样例，不连接公网或发送消息。`report.json` 的 `expected` 是应观察的结果，实际结果在各步输出中；成功退出不替代内容核对。

输入性质：原创合成时间序列，含负零与 NaN payload。

应观察：闭区间返回负零 bits=9223372036854775808 与 NaN bits=9221120237041090626，完整校验成功。

具体命令和输入路径见 [使用任务](USE-CASE.md) 与 [机器可读流程](examples/use-case.json)。只把这个脚本当复现入口，不把通用运行器计作核心技术贡献。

## 实现与已有项目的关系

MoonBit 执行 XOR/位流、CRC、分块增量编码及范围索引；Node 执行文件发布、异步输入输出及 CLI。

Gorilla 是既有算法；本轮未找到同范围 MoonBit 压缩库。贡献是该生态的可复用实现和块索引/完整性工作流，不是算法首创，也不把自有 GOR2 容器说成 Prometheus TSDB 文件。

同类项目和检索边界见 [DUPLICATION](DUPLICATION.md)。查重用于避免错误的首创表述；关键词零结果不能证明生态空白，Node 宿主能力也不计为 MoonBit 原生 I/O。

库使用从 [公共 API](pkg.generated.mbti) 和根包源码开始；可在本 checkout 的消费包中导入 `"xie-wei10/gorilla"`。源码中的网络/文件宿主入口及完整参数仍见 [完整使用说明](README-BEFORE-VALUE-REWORK.md)。是否已发布到 Mooncakes 需另核实，本文不把 `moon add` 的下载成功作为已完成事项。

## 验证与边界

前一轮工程验证 10 组真实归档流程及十万样本范围读取通过；独立容器向量为保存的参考重放，未冒充前一轮工程验证重新运行 Go oracle。

[上一轮工程验证](evidence/innovation-review-20260922/results.json) 与 [本轮最小任务回执](evidence/value-rework-20260922/use-case.json) 分开。历史参考版本、golden 重放、本机 peer、真实第三方服务端和本次样例是不同证据，不能合并成“全部生产验证”。

常规核心检查可运行 `moon check --target js`、`moon test --target js`、`moon test --target wasm-gc`。专项命令：

```sh
node tools/test-archive.mjs --golden
```

专项所需的参考环境和历史版本见原使用说明及 TESTING 文档；本轮回执只记录实际执行项，不声称上面所有参考服务在任意环境即装即跑。

默认范围读取只检查选中的块；完整归档校验需 verify/--verify-all。原始 XOR chunk 互通不等于整个 TSDB 兼容。

## 复审材料状态

Gorilla 算法已有，GOR2 不是 Prometheus 完整 TSDB 格式，性能不宣称追平。

2026-09-22 匿名新克隆成功；默认分支 `main`，核验公开提交 `1934afceef052621c668119279f210624bb89692`。本轮源码修订仅在本地，尚未推送；此记录不证明当时报名表中的地址正确，也不证明新修订已上线。

[申报草稿](PROPOSAL.md) 已压缩为 30 行以内，并单独标明本项目仓库；[复核说明](REVIEW-RESPONSE.md) 区分材料错误、功能变化及尚未解决的问题。没有编造用户、设备接入、生产部署或评审认可。
