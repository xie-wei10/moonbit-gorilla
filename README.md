# Gorilla 时序压缩 · 0.4.0

## 获取与验证入口

公开源码：[github.com/xie-wei10/moonbit-gorilla](https://github.com/xie-wei10/moonbit-gorilla)；MoonBit 模块名为 `xie-wei10/gorilla`。

从源码运行：`git clone https://github.com/xie-wei10/moonbit-gorilla.git` 后进入该目录，按下文和 [TESTING.md](TESTING.md) 安装所需工具。仓库公开不等于已在 Mooncakes 发布，不承诺 `moon add` 当前可用。

查看 [GitHub Actions](https://github.com/xie-wei10/moonbit-gorilla/actions) 时请核对 run 的 commit SHA；历史 evidence、旧 ZIP 与本地测试不能替代当前提交的 CI 结果。下文保留各版本的验证范围和兼容性限制。

> 历史开发记录（以下发布/归档状态不代表当前仓库；当前入口见文首）：MoonBit 原创压缩库与 Node 文件宿主，支持原有 GOR1、兼容 Prometheus 的原始 XOR chunk，以及新增带 CRC 校验和索引的 GOR2 容器。全部在本地，未上传或发布。完整追平目标仍未完成。

## 真实文件使用

Node.js 24，已附实际 MoonBit 编译引擎：

```powershell
node tools/archive-cli.mjs encode samples.txt output.gor2 --block-size 4096
node tools/archive-cli.mjs decode output.gor2
node tools/archive-cli.mjs range output.gor2 -1000 1000
node tools/archive-cli.mjs range output.gor2 -1000 1000 --verify-all
node tools/archive-cli.mjs info output.gor2
node tools/archive-cli.mjs verify output.gor2
node tools/archive-cli.mjs xor-encode samples.txt output.xor
node tools/archive-cli.mjs xor-decode output.xor
```

文本每行两个十进制整数：`signed_int64_timestamp raw_uint64_bits`；值保留正负零、无穷和 NaN payload，不经过 JSON 浮点舍入。输入 `-` 读取 stdin。GOR2 要求时间不递减，允许重复；原始 XOR chunk 可记录任意 Int64 时间顺序。GOR2 encode 流式读取，只保留当前块、有限批次和索引，完成后同步临时文件并以同目录硬链接原子发布；目标已存在则报错，不覆盖。失败或取消清理本次临时文件。底层文件系统需支持同目录文件硬链接。

range 为闭区间，按索引跳过不相交块。默认只验证索引和读到的块；`--verify-all` 另外验证未选中负载。decode 的 stdout 可以先输出有效前缀，只有退出码 0 才证明整个索引和尾部都通过，管道消费者应检查退出码。`verify` 显式扫描全部块。

旧 GOR1 CLI `node tools/blocks.mjs encode|decode|range ...` 保持原格式与行为，range 仍验证整个旧块。原网页用 `./start-review.ps1`，没有将网页演示当作新文件格式的 UI 验收。

## MoonBit API

- `Encoder/Decoder`、`encode/decode/decode_range`：原有 GOR1；逐条追加、独立快照、完整块迭代和严格尾部检查。
- `XorEncoder/XorDecoder`、`encode_xor/decode_xor`：Prometheus 3.14.0（module v0.314.0）原始 XOR chunk；Int64 时间、UInt64 值、快照、封闭编码器、最多 65535 条。默认严格尾部；`strict=false` 与参考迭代器一样在样本数处停止。
- `ArchiveEncoder`：先写 `archive_header()`，按 append 返回的完整块写出，最后写 finish 返回的尾块、索引和 trailer。已完成块不保存在编码器内。
- `ArchiveDecoder.feed`：接受任意分片，每次最多 65536 字节；校验完整块后返回样本。`finish` 验证最终索引与已消费块一致；出错后保持失败状态。
- `ArchiveIndex`：校验索引、二分定位范围、校验并解码指定块。`crc32` 提供 IEEE CRC-32。

完整公开接口见 `pkg.generated.mbti`。格式、字段与 CRC 覆盖范围见 [FORMAT.md](FORMAT.md)。GOR2 是本项目自定义容器，负载的 XOR chunk 可与 Prometheus 交换；GOR2 不是 Prometheus TSDB segment/block/WAL 格式。

## Node 流式 API

```javascript
import {writeArchive, readArchive, ArchiveFile} from './tools/archive.mjs';
await writeArchive('series.gor2', asyncIterableOfSamples, {blockSize: 4096, signal});
for await (const sample of readArchive('series.gor2')) {
  // timestamp 和 bits 为精确十进制字符串
}
const file = await ArchiveFile.open('series.gor2');
try {
  for await (const sample of file.range('-1000', '1000')) { /* ... */ }
  console.log(file.bytesRead); // 可以观察索引查询实际读取量
} finally {
  await file.close();
}
```

也接受 BigInt 或安全整数输入；不安全的 JavaScript Number 被拒绝。提前结束 readArchive 的 iterator 会释放文件/桥接会话，但不表示未读后缀已经校验。关闭 ArchiveFile 前需要结束其活动 iterator。没有后台服务或系统配置修改。

## 当前独立证据

- 固定未修改 Prometheus v0.314.0 的 277 个案例，编码字节及双向样本一致；其中 38 个固定黄金向量也在每个 MoonBit 后端执行。
- 144 个原有 GOR1 场景由独立 Python 规格模型核对精确字节和双向样本；它是自定义格式对照，不冒充上游格式。
- GOR2 用 Python struct/zlib 构造/检查容器、官方 Go 库处理负载，5 个案例全字节及双向样本一致。
- 10 组文件/流式/CLI 集成检查包含 10 万样本、窄查询读取不足文件 10%、取消与防覆盖、区间外损坏、提前退出和会话释放。
- NOAA 日均 CO2、USGS 月度地震震级/深度及 3 类合成序列做实际字节与计时对照；数据来源、SHA256、转换与运行环境全部记录。

构建/复现命令和证据口径见 [TESTING.md](TESTING.md)。优化把逐位移位改为每次处理至多一个字节，并使用前导/尾随零计数；字节格式不变。实际压缩大小与参考一致，MoonBit JS 速度仍落后于同机原生 Go，不能据此宣称性能追平。CRC 检测损坏而非密码学认证。

## 资源与剩余差距

GOR1 仍最多 100000 条、时间 0..2^53-1；原始 XOR chunk 最多 65535 条、2 MB。GOR2 每块最多 65535 条、2 MB 负载，最多 65536 块；索引最多约 2.36 MB。编码/解码宿主使用有界输入批次，但索引内存随块数增长。单次 feed 大小不等于整个文件上限。

尚缺论文原始块/Beringei 等其他位流、完整 TSDB 格式和多序列管理、更广泛真实数据/长期故障/跨平台验证，以及代表性吞吐与内存的进一步优化。新 GOR2 路径有分片解码，旧 GOR1/原始 XOR 迭代器仍接收完整块。完整差距见 [FEATURES.md](FEATURES.md)。

> 历史开发记录（以下发布/归档状态不代表当前仓库；当前入口见文首）：算法参考 [Gorilla 论文](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf) 和 [Prometheus chunkenc](https://github.com/prometheus/prometheus/tree/v3.14.0/tsdb/chunkenc)。生产代码为原创，不复制上游源码，MIT；Go 官方库仅为开发测试依赖。独立仓库、无 remote、远端 CI 未运行；旧 ZIP/Git bundle 暂未刷新。
