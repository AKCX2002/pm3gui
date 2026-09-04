# 安全策略

## 支持范围

安全修复以最新 GitHub Release 和 `main` 分支为准。旧版本可能不会单独回移修复，请先确认问题在当前代码中仍可复现。

## 报告漏洞

如果仓库的 **Security** 页面提供 **Report a vulnerability**，请优先使用该私密渠道。若该入口不可用，请创建一个不含漏洞细节的 Issue，请求维护者提供私下联络方式。

报告建议包含：

- 受影响版本、提交和操作系统；
- 可复现步骤、影响及最小证明；
- 已知缓解措施；
- 已去除凭据、卡片 UID、设备标识和个人路径的日志。

请勿在公开 Issue、讨论或 Pull Request 中发布可直接利用的细节或敏感数据。收到报告后，维护者会先确认影响和处理范围，再协调修复与披露时间。

PM3 GUI 自身代码、构建流程和打包问题由本仓库处理。Proxmark3 client 或固件中的问题请同时参考 [RfidResearchGroup/proxmark3](https://github.com/RfidResearchGroup/proxmark3) 的上游安全渠道。
