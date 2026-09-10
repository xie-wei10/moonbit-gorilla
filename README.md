# Gorilla 时序压缩

MoonBit 0.3.0 本地压缩库。时间戳 delta-of-delta 与 64 位 XOR 编码，支持逐条追加、快照和逐条解码。
使用自定义 GOR1 容器，0.3 保持既有 GOR1 字节格式；不等同于 Facebook 或 Prometheus TSDB 的位流格式。

## 本地文件使用

每行输入两个十进制整数：timestamp raw_uint64_bits。值采用原始位模式，保留正负零、无穷和 NaN payload。

```powershell
node tools/blocks.mjs encode sample.txt output.gor1
node tools/blocks.mjs decode output.gor1
node tools/blocks.mjs range output.gor1 60 120
```

encode 创建新文件，已有输出文件会报错，不覆盖。decode/range 输出原始时间戳和 UInt64 位模式，
不会经过 JavaScript 浮点数转换。范围为闭区间。输入/输出错误返回非零退出码。
旧 `tools/cli.mjs` 和网页演示仍可使用；`./start-review.ps1` 启动独立本地网页。

## 逐条 API

```moonbit
let encoder = @gorilla.Encoder::new()
encoder.append({ timestamp: 0L, bits: 0x3ff0000000000000UL })
let prefix = encoder.snapshot()
encoder.append({ timestamp: 60L, bits: 0x4000000000000000UL })
let block = encoder.finish()
let decoder = @gorilla.Decoder::new(block)
while decoder.next() is Some(sample) {
  // process sample.timestamp and sample.bits
}
```

- Encoder 直接填充压缩字节，不再为每一位分配一个 Int，也不保留完整样本数组。
- snapshot 返回带头部和零填充的独立 GOR1 副本，之后可继续追加；旧快照不会变化。
- finish 封闭编码器，可重复读取结果；封闭后 append 报错。非法追加不会改变已有数据。
- length/encoded_size 返回样本数与当前块字节数，不需要复制快照。
- Decoder 接收完整字节块，next 逐条返回 Sample 或 EOF；状态大小不随样本数增长。
  它是样本迭代器，尚不是接收任意网络字节分片的解码器。
- Decoder.finish 丢弃并验证剩余样本，is_verified 说明整个块是否已读完且验证成功。
  仅读取前几条不代表整个块有效；尾部检查在返回最后一条样本前完成。出错后解码器保持失败状态。

批量 encode/decode 复用这些接口。decode_range 仍扫描并验证完整块，但只保存命中的样本，
不再先产生完整解码数组。即使损坏部分位于查询区间之外，也会报错。

## 边界与验证

每块最多 100,000 样本；时间戳范围 0..9,007,199,254,740,991，允许重复、不允许倒序。
解码块上限 2,000,000 字节；拒绝错误头部、截断、超限、非法 XOR 窗口、非零填充和额外字节。

本轮 13 项项目 JS 测试通过，覆盖固定格式字节、所有特殊位模式、截断、快照生命周期、失败状态，
以及 100,000 样本的追加与逐条验证。固定 NaN payload、等间隔样本的块小于 26,000 字节，
这只是该特定测试数据的结果，不代表任意序列压缩率。
5 个本地文件 CLI 场景通过：编码、解码、区间输出、防覆盖、区间外损坏仍报错。
证据见 evidence/stream-focused-validation.json；本轮未重新验证其他项目或执行独立上游位流对照。

安装 MoonBit 后 `./verify.ps1` 执行完整本项目流程；`pkg.generated.mbti` 为生成的公共 API。
位格式详见 FORMAT.md。文件 CLI 为便利入口，会整体读取输入文件；MoonBit 流式 API 不需要样本数组。

## 仍需完善

独立编解码对照、更多真实数据压缩率/吞吐量测量、分块索引与随机访问、参考实现位流兼容模式、
接收部分字节的增量输入接口。GOR1 当前没有校验和，合法位模式中的位翻转并不都能检测到。
不声称已全面追平或具有数据库查询规划/事务能力。

算法来源：[Gorilla 论文](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf)。实现为本地原创，未复制上游源码，MIT。
查重范围见 DUPLICATION.md。独立仓库仅本地保存，未上传/发布；旧 ZIP/bundle 是历史快照，本轮未重打包。
