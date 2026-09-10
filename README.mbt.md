# 可执行 API 示例

增加闭区间时间查询，保留原始样本顺序。这些例子调用公开 API，并随 `moon test` 执行。

```mbt check
///|
test "closed range query filters decoded points" {
  let b = @gorilla.encode([
    { timestamp: 1L, bits: 0UL, },
    { timestamp: 2L, bits: 1UL, },
    { timestamp: 3L, bits: 2UL, },
  ])
  assert_eq(@gorilla.decode_range(b, 2L, 2L), [{ timestamp: 2L, bits: 1UL, }])
  assert_eq(@gorilla.decode_range(b, 4L, 5L), [])
  assert_true(
    try {
      ignore(@gorilla.decode_range(b, 5L, 4L))
      false
    } catch {
      _ => true
    },
  )
}
```

限制：查询会顺序解码整个块；没有索引、持久化或数据库查询规划。
