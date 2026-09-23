# 0.5.0 生态查询接入验证

[本轮命令与退出码](evidence/moonpromql-integration-20260923/LOCAL-CHECKS.json)、[11组流程报告](evidence/moonpromql-integration-20260923/QUERY-CHECKS.json)、[本机进程采集产物](evidence/moonpromql-integration-20260923/live-process-example/report.json)。

```sh
moon fmt
moon info
moon check --target js
moon test --target js
moon test --target wasm-gc
moon build --target js
node tools/refresh-engines.mjs
node examples/run-metrics-query.mjs
node tools/test-query-archive.mjs
node tools/test-archive.mjs --golden
```

新增3组MoonBit检查：AST窗口计算（offset/@/lookback/标量/小数拒绝）、压缩样本与上游左开右闭区间求值、负零/NaN/stale/时间精度/重复样本标签边界。11组Node流程检查包括5个表达式的全量与裁剪对照、无文件标量、资源上限与文件释放、身份冲突、NaN、局部/完整校验差异、提前取消。

核心JS/Wasm-GC全量测试、原demo/CLI/block及XOR/GOR1/archive golden重放均在本轮运行。golden重放不等于重新启动Go独立参考；不复用旧日期的性能或覆盖率成绩作为新证据。

示例采集当前进程真实指标但无生产采用含义；保存的报告数值仅是本次运行。4096点测试是原创确定性输入；全量与裁剪两侧用同一上游查询引擎，验证存储和窗口不改变结果，不证明完整Prometheus兼容性。

CI增加新例子和文件/查询流程检查，未在远端运行。旧行为/详细容器方法见 README-BEFORE-VALUE-REWORK.md，原位模式和查询数学语义不能混淆。
