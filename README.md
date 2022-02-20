## 给图标包作者的数据库 - 服务端

### 本项目提供什么？
- 应用名 / 包名 / 启动项名互查功能 -> [去查询](https://app-tracker.k2t3k.tk)
- 客户端应用信息上传功能 -> [去上传](https://github.com/Oblatum/App-Tracker-for-Icon-Pack-Client-Side-Android-Version/releases)
- 图标包申请统计功能（需要图标包客户端支持，API 文档施工中，试用请提交 Issue）

### 如何搭建服务端？

#### Docker

服务端使用 [Vapor]() 搭建而成，你可以参考 [Vapor 的官方文档](https://vapor.k2t3k.tk/)，其中包含[如何使用 Docker 来启动服务](https://vapor.k2t3k.tk/4.0/deploy/docker/)。


#### 自行构建

你可以参考 [Vapor 部署到 DigitalOcean](https://vapor.k2t3k.tk/4.0/deploy/digital-ocean/#swift) 中的内容，从安装 Swift 开始。

如果你使用 Debian/Ubuntu，你还可以使用 [Swift Community Apt Repository](https://www.swiftlang.xyz)，通过 `apt` 包管理器进行安装。

⚠️ 注意，构建完成后，首次运行前请先迁移数据库，运行 `.build/release/Run migrate`，你可能需要将二进制可执行文件路径替换成你的实际路径。