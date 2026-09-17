# GOR1 格式

这是本项目的格式，不是论文或 Prometheus 的标准交换格式。所有字段按最高位优先写入，整数头部为大端。

1. 4 字节 ASCII GOR1，随后 4 字节无符号样本数。
2. 首条样本：64 位时间戳与 64 位原始值。
3. 后续时间戳：d = current_time - previous_time；dd = d - previous_delta；第一条之后 previous_delta 初始为 0。

| dd 范围 | 前缀 | 附加位 |
| --- | --- | --- |
| 0 | 0 | 无 |
| -63..64（不含 0） | 10 | 7 位 dd+63 |
| -255..256 | 110 | 9 位 dd+255 |
| -2047..2048 | 1110 | 12 位 dd+2047 |
| 其余 | 1111 | 64 位二进制补码 dd |

值部分为 current_bits XOR previous_bits。
零 XOR 写单个 0；非零先写 1。
若能复用上一窗口，再写 0 和该窗口全部有效位；否则写 1、6 位前导零数、6 位有效位数（0 表示 64）、有效位。
尾随零数由 64-前导零-有效位数计算。首次非零 XOR 必须定义窗口。
最后补 0 至整字节；不允许附加字节。编码器在 finish/snapshot 时写入实际样本数，不写结束哨兵。

0.3 的写入器按字节打包，格式未改变。Decoder 会检查样本数、时间范围和顺序、窗口范围与尾部，
但这不是带校验和的容器，不能证明所有损坏都会被发现。


# Prometheus XOR chunk

新增独立 `encode_xor/decode_xor` 和 `XorEncoder/XorDecoder` API，对照固定 Prometheus 3.14.0（Go module v0.314.0）。它是原始 XOR chunk，不包含 Prometheus segment、block、WAL 或索引格式。

- 2 字节大端样本数，最多 65535；空块正好 2 字节。
- 首时间戳为 signed varint（zigzag + LEB128），首值为 64 位原始位模式。
- 第二时间戳为 unsigned varint delta；之后 delta-of-delta 使用 0、14、17、20、64 位分组和相应 0/10/110/1110/1111 前缀；短分组的负下界为 `-(2^(w-1)-1)`，正上界为 `2^(w-1)`。
- 非零值 XOR 使用 5 位前导零数（最大 31）、6 位有效位数（0 表示 64），或复用先前窗口。
- 保留完整 signed Int64 时间戳与 UInt64 值位模式。原始 chunk 不强制排序；delta 算术与参考一致地按 64 位回绕。
- 默认严格检查零填充和无额外字节；`strict=false` 与参考迭代器一样在样本数处停止。没有校验和，不能检测所有合法位模式中的损坏。

# GOR2 可索引容器

这是本项目原创的带校验容器，负载采用上述兼容的原始 XOR chunk。它不是 Prometheus TSDB segment 文件。多字节定长数均为大端，时间边界用 64 位二进制补码。

```
header       8 bytes: "GOR2" 01 00 00 00
block        repeated zero or more times
index        IDX2 + entries + CRC32
trailer     12 bytes: index_length:u64 + "END2"
```

每个 block：

| 字段 | 字节 |
|---|---:|
| BLK2 | 4 |
| sample_count | 4 |
| payload_length | 4 |
| first_timestamp | 8 |
| last_timestamp | 8 |
| Prometheus XOR payload | payload_length |
| CRC32 | 4 |

CRC32 为 IEEE/zlib 算法，覆盖 BLK2 开始至负载结束。标准向量 `123456789` 的结果为 `cbf43926`。每块 1..65535 条；块内及块间时间不递减，允许重复时间。first/last/count 必须与实际解码一致。单负载上限 2000000 字节。

index 由 `IDX2`、4 字节 entry_count、每项 36 字节的条目和末尾 4 字节 CRC32 组成。每项依次为 `offset:u64, frame_length:u32, sample_count:u32, first:i64, last:i64, frame_crc32:u32`。索引 CRC 覆盖前面的整个索引。条目 offset 必须连续，从 8 开始；最后块恰好结束于索引开始。索引最多 65536 项，字节上限 2359308。尾部 index_length 包含索引 CRC、不含自身 12 字节。

空容器为 32 字节；无额外尾部字节。CRC 是损坏检测而非密码学认证。通过重新计算 CRC 的恶意修改仍需另行认证，不能由该格式证明可信来源。

流式编码器只保留当前块和索引元数据。先输出 `archive_header()`，立即写出每次 append 返回的完整块，最后写 finish 返回的剩余块/索引/尾部。流式解码 feed 最大 65536 输入字节，逐块检查后输出样本；必须 finish 成功才能证明最终索引/尾部完整。提前停止只验证已消费的前缀。

索引查询按块 last_timestamp 二分定位，再扫描相交块；选中块做完整 CRC 与样本边界检查。未选中负载不被读取，也不声称经过验证。完整 verify 或 `verifyAll=true` 读取全部块。文件和网络不是受信任的索引来源，索引长度、CRC、顺序、连续偏移、总大小均在分配/查询前检查。
