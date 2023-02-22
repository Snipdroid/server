## 给图标包作者的数据库 - 服务端

您当前位于 **开发分支**，请注意，此分支可能不稳定。

![API](https://img.shields.io/website?down_color=lightgrey&down_message=Offline&label=API&up_color=green&up_message=Online&url=https%3A%2F%2Fapptracker-api.cn2.tiers.top)
![Website](https://img.shields.io/website?down_color=lightgrey&down_message=Offline&label=Website&up_color=green&up_message=Online&url=https%3A%2F%2Fapp-tracker.butanediol.me)

本项目为解决图标包/主题作者寻找包名困难的问题而生。本质上并不是面相广大用户，但我们希望看到此软件的你能抽出两分钟，下载并提交你设备上的应用列表，帮助我们完善数据库。

请放心，本软件并不会收集或上传任何个人信息，只有应用的名称、包名和启动项会被提交，本项目完全开源，请放心使用。

### 项目组成

- AppTracker Server 本体
- PostgreSQL 数据库
- S3 存储服务（可选）

### TODO

* [x] 上传鉴权

### API

查看[API 文档](https://www.apifox.cn/apidoc/shared-ecf7eba1-36c2-4237-a2d2-ffcf0d071833/api-43668452)

### 本项目提供什么？

- 应用名 / 包名 / 启动项名互查功能 -> [去查询](https://app-tracker.butanediol.me)
- 客户端应用信息上传功能 -> [去上传](https://github.com/Oblatum/App-Tracker-for-Icon-Pack-Client-Side-Android-Version/releases)
- 图标包申请统计功能（需要图标包客户端支持，API 文档施工中，试用请提交 Issue）

### Getting Started

#### Quick Start with Docker

Prebuilt Image: `butanediol/apptracker`

Available tags: `latest`, `dev`

##### Docker Compose

1. 安装 Docker 环境。修改 `docker-compose.yaml` 文件中你需要修改的变量（可选）。
2. 运行 `docker compose up -d` 启动本体和数据库
3. 运行 `docker compose up migrate` 进行数据库迁移
4. 大功告成。

服务端使用 [Vapor]() 搭建而成，你可以参考 [Vapor 的官方文档](https://docs.vapor.codes)，其中包含[如何使用 Docker 来启动服务](https://docs.vapor.codes/4.0/deploy/docker/)。

#### 自行构建

你可以参考 [Vapor 部署到 DigitalOcean](https://docs.vapor.codes/4.0/deploy/digital-ocean/#swift) 中的内容，从安装 Swift 开始。

如果你使用 Debian/Ubuntu，你还可以使用 [Swift Community Apt Repository](https://www.swiftlang.xyz)，通过 `apt` 包管理器进行安装。

⚠️ 注意，构建完成后，首次运行前请先迁移数据库，运行 `./.build/release/Run migrate`，你可能需要将二进制可执行文件路径替换成你的实际路径。
