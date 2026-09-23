# 场景：本机任务的指标快照归档与离线诊断

适用条件：已有按时间排序的指标，需要在任务结束后保存、读取短时段，并使用已有MoonPromQL查询；不需要搭完整Prometheus服务。本例只展示这一工作流，不声称有人已上线采用。

`node examples/run-metrics-query.mjs` 每10ms左右读取一次当前示例Node进程的RSS/heap，共24次、48样本。用实际Date.now毫秒与IEEE754位模式写入两份GOR2；清单保留metric、kind标签和时间单位。精确读回并比对原样本，然后执行上游avg_over_time，与同批未压缩样本结果作断言。结果与文件保存在新建临时目录。

应用可显式提供文件清单：

```js
import {queryArchives} from './tools/query-archive.mjs';
const report = await queryArchives({
  series: [{file: '/your/metrics/rss.gor2', metric: 'process_memory_bytes', labels: [['kind','rss']]}],
  query: 'avg_over_time(process_memory_bytes[5m])',
  at: '1790000000000', // replace with the actual integer millisecond endpoint
  verifyAll: false,
});
console.log(report.result, report.window, report.reads);
```

时间窗口来自上游AST，包含range、offset、@与瞬时lookback，应用无需手动估算。若需要整份文件的完整性证明，设verifyAll=true；默认只检查索引和选中块。series清单必须包含查询所需的所有相关序列，不能把只传入一部分数据解释成完整系统监控。

原工具 archive-cli.mjs 仍可独立做编码、范围读取与verify。对采集来源的扩展由应用负责；本版没有Prometheus scrape/OTLP exporter、remote write/read服务或数据自动发现。元数据清单尚未嵌入GOR2，不要丢失标签与毫秒单位。报告中的查询值是数学结果，原始NaN等特殊bits只能走归档接口。
