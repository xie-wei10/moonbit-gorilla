# 保留特殊浮点位模式的区间归档

将时间戳/原始浮点位模式归档，并按时间索引读取小范围、定位坏块；数据仍可按 Prometheus XOR chunk 交换。

## 输入、操作、输出

原创合成时间序列，含负零与 NaN payload。

最简运行：先按 README 构建，然后 `node examples/run-use-case.mjs`。它自动创建输出目录并执行下面命令。下列 `{out}` 是运行器替换的实际目录，不是直接输入 shell 的变量；stdin 文件由运行器传递，以避免 Windows 与 POSIX 重定向差异。

```text
node tools/archive-cli.mjs encode examples/use-case/samples.txt {out}/samples.gor2 --block-size 2
node tools/archive-cli.mjs range {out}/samples.gor2 1000 2000 --verify-all
node tools/archive-cli.mjs verify {out}/samples.gor2
```

观察：闭区间返回负零 bits=9223372036854775808 与 NaN bits=9221120237041090626，完整校验成功。

每一步输出见实际目录下 `step-N.stdout.txt` / `step-N.stderr.txt`；本轮已保存回执见 `evidence/value-rework-20260922/use-case.json`。

## 为什么保留这个实现

需要原始浮点位模式、块索引和坏块定位时评估；如果只是 JSON 导出，无须引入该自有容器。

Gorilla 是既有算法；本轮未找到同范围 MoonBit 压缩库。贡献是该生态的可复用实现和块索引/完整性工作流，不是算法首创，也不把自有 GOR2 容器说成 Prometheus TSDB 文件。

## 不能由样例推出的结论

默认范围读取只检查选中的块；完整归档校验需 verify/--verify-all。原始 XOR chunk 互通不等于整个 TSDB 兼容。

该样例是可修改的使用入口，不能证明存在真实用户、全部兼容或性能领先。继续投入的依据应是明确的输入或接入需求；若对接任务用既有成熟库即可完成，应优先复用而不是为保留参赛数量扩张本项目。
