# MoonBit Gorilla 时序压缩库 · 项目申报书

## 一、项目名称

MoonBit Gorilla 时序压缩库

## 二、项目说明

MoonBit 实现自有 GOR1、Prometheus 原始 XOR chunk 兼容路径，以及带索引和 CRC 的自定义 GOR2 容器。Int64 时间戳和 UInt64 浮点位模式避免 JSON 双精度损失。

## 三、方向与通用性

基础软件与数据压缩。用于时序归档、区间查询和位级编码研究；GOR2 不是 Prometheus TSDB segment/block/WAL 格式。

## 四、应用场景

Node archive-cli 编码文件、按闭区间查询样本，输出通过同目录临时文件与硬链接发布，已存在的目标不覆盖；按需 --verify-all 检查未读取块。

## 五、功能与验证边界

记录有 Prometheus 3.14.0 的 277 个编码/双向样本比较及固定黄金向量。真实数据和计时在仓库保留，MoonBit JS 与原生 Go 的速度差距如实披露；有限样本不证明整体性能追平。

## 六、原创性与参考材料

依据 Gorilla 论文及 Prometheus chunkenc（Apache-2.0，https://github.com/prometheus/prometheus/tree/v3.14.0/tsdb/chunkenc）独立实现，原创代码 MIT。Go 库只作开发对照，不复制进生产源码；真实数据来源及哈希见 evidence。

## 七、仓库链接

https://github.com/xie-wei10/moonbit-gorilla
