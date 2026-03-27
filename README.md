# Mihomo Proxy Docker

[![Build](https://github.com/ba0gu0/mihomo-proxy/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/ba0gu0/mihomo-proxy/actions/workflows/docker-publish.yml)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue?logo=docker)](https://www.docker.com/)
[![Mihomo](https://img.shields.io/badge/Mihomo-Meta-purple)](https://github.com/MetaCubeX/mihomo)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

基于 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 的增强版 Docker 镜像，集成 [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) Web UI 管理界面。

## 📦 镜像地址

```bash
# 拉取最新镜像
docker pull ghcr.io/ba0gu0/mihomo-proxy:latest
```

## 🚢 发布流程

仓库现在采用“先出 `tag`，再按 `tag` 构建镜像”的方式发布，版本号唯一来源是 Git tag。

- 自动检查: GitHub Actions 会在每周五 `09:00`（北京时间，`01:00 UTC`）运行一次 `Create Release Tag`，检查上游 `metacubex/mihomo:latest` 的 digest 和 `MetaCubeX/Yacd-meta` 的 `gh-pages` 最新 commit。
- 自动发布: 只有检测到上游变化时，才会基于当前最新 `vX.Y.Z` tag 自动创建下一个 `patch` 版本，例如 `v1.0.0 -> v1.0.1`。
- 自动构建: 只要仓库出现新的 `vX.Y.Z` tag，`docker-publish.yml` 就会自动构建并推送 GHCR 镜像，镜像 tag 与 Git tag 一致。
- 手动发布: 推荐在 GitHub Actions 里手动运行 `Create Release Tag`，选择 `patch` / `minor` / `major` / `exact`。这样会先创建正确的 Git tag，再自动触发镜像构建。
- 手动指定版本: 如果选择 `exact`，请输入新的语义化版本号，例如 `1.2.3` 或 `v1.2.3`。工作流会校验它必须大于当前最新 tag。
- GitHub Release 页面: 如果你直接在 Releases 页面手动发版，也请先创建一个新的 `vX.Y.Z` tag。构建实际是由 tag 触发的，所以不要复用旧 tag。
- 上游状态记录: 每次新 tag 都会把本次使用的 `mihomo-digest` 和 `yacd-commit` 写进 tag 注释和 GitHub Release 说明，供下一次自动检查直接对比。

版本对齐规则：

- 自动发布只会在上游变化时基于仓库中最新的 `vX.Y.Z` tag 继续递增。
- 手动发布也走同一套版本规则，因此不会出现自动版本和手动版本各自漂移的问题。
- `latest` 镜像始终指向最近一次成功发布的正式版本，具体语义化版本镜像例如 `ghcr.io/ba0gu0/mihomo-proxy:1.0.1` 则与 Git tag `v1.0.1` 一一对应。
- 构建时会强制拉取最新基础镜像并禁用构建缓存，避免 `metacubex/mihomo:latest` 或 `Yacd-meta gh-pages` 因缓存命中而没有真正更新。

## ✨ 功能特性

- 🚀 **混合代理** - HTTP/SOCKS5 统一端口代理服务
- 🎛️ **Web UI** - 集成 Yacd-meta 可视化管理界面
- 📥 **订阅支持** - 自动下载和定时更新订阅配置
- ⚙️ **环境变量** - 灵活的配置覆盖机制
- 📁 **配置挂载** - 支持挂载自定义配置文件
- 🔄 **自动重载** - 订阅更新后自动重载配置
- 🏥 **健康检查** - 内置容器健康检查机制

## 🚀 快速开始

### 构建镜像

```bash
docker build -t mihomo-proxy .
```

### 基础使用

```bash
# 纯代理模式 (无管理界面)
docker run -d -p 7890:7890 ghcr.io/ba0gu0/mihomo-proxy:latest

# 带管理界面
docker run -d -p 7890:7890 -p 9090:9090 \
  -e API_SECRET=your_password \
  -e SUBSCRIPTION_URL=https://订阅地址.com \
  ghcr.io/ba0gu0/mihomo-proxy:latest
```

访问管理界面: http://localhost:9090/ui

### Docker Compose

```bash
# 编辑 docker-compose.yaml 配置后启动
docker compose up -d --build
```

## ⚙️ 环境变量

### 代理配置

| 变量             | 默认值    | 说明                                        |
| ---------------- | --------- | ------------------------------------------- |
| `MIXED_PORT`   | `7890`  | 混合代理端口 (HTTP + SOCKS5)                |
| `ALLOW_LAN`    | `true`  | 允许局域网访问                              |
| `PROXY_MODE`   | `rule`  | 代理模式:`rule` / `global` / `direct` |
| `GLOBAL_PROXY` | `PROXY` | 全局模式下选中的代理组名称                  |

### 管理界面

| 变量           | 默认值   | 说明                                   |
| -------------- | -------- | -------------------------------------- |
| `API_PORT`   | `9090` | 管理 API 端口                          |
| `API_SECRET` | *(空)* | API 密钥，**设置后启用管理界面** |

### 订阅配置

| 变量                      | 默认值   | 说明                    |
| ------------------------- | -------- | ----------------------- |
| `SUBSCRIPTION_URL`      | *(空)* | 订阅地址                |
| `SUBSCRIPTION_INTERVAL` | `24`   | 订阅自动更新间隔 (小时) |

### 其他

| 变量          | 默认值            | 说明                                                                 |
| ------------- | ----------------- | -------------------------------------------------------------------- |
| `LOG_LEVEL` | `info`          | 日志级别:`silent` / `error` / `warning` / `info` / `debug` |
| `TZ`        | `Asia/Shanghai` | 时区设置                                                             |

## 📖 使用示例

### 1. 挂载配置文件

直接挂载你的 Mihomo 配置文件：

```bash
docker run -d \
  -p 7890:7890 \
  -v ./config.yaml:/root/.config/mihomo/config.yaml \
  ghcr.io/ba0gu0/mihomo-proxy:latest
```

### 2. 使用订阅链接

自动下载订阅配置并定时更新：

```bash
docker run -d \
  -p 7890:7890 \
  -p 9090:9090 \
  -e API_SECRET=my_password \
  -e SUBSCRIPTION_URL=https://your-subscription-url \
  -e SUBSCRIPTION_INTERVAL=12 \
  ghcr.io/ba0gu0/mihomo-proxy:latest
```

### 3. 全局代理模式

设置为全局代理模式，并指定使用的代理组：

```bash
docker run -d \
  -p 7890:7890 \
  -p 9090:9090 \
  -e API_SECRET=my_password \
  -e PROXY_MODE=global \
  -e GLOBAL_PROXY=节点选择 \
  -e SUBSCRIPTION_URL=https://your-subscription-url \
  ghcr.io/ba0gu0/mihomo-proxy:latest
```

### 4. 作为其他容器的代理

```yaml
# docker-compose.yaml
services:
  mihomo:
    image: ghcr.io/ba0gu0/mihomo-proxy:latest
    ports:
      - "7890:7890"
    environment:
      - API_SECRET=admin123
      - SUBSCRIPTION_URL=https://your-sub-url

  app:
    image: your-app
    environment:
      - HTTP_PROXY=http://mihomo:7890
      - HTTPS_PROXY=http://mihomo:7890
    depends_on:
      - mihomo
```

### 5. 持久化数据

```yaml
services:
  mihomo:
    image: ghcr.io/ba0gu0/mihomo-proxy:latest
    ports:
      - "7890:7890"
      - "9090:9090"
    environment:
      - API_SECRET=your_password
    volumes:
      - mihomo-data:/root/.config/mihomo
    restart: unless-stopped

volumes:
  mihomo-data:
```

## 🤖 AI 服务代理示例

为需要访问 OpenAI、Claude、Gemini 等 AI 服务的应用提供干净的代理网络。

### 配合 CLIProxyAPI 使用

[CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) 是一个 AI API 聚合服务，需要通过代理访问各大 AI 服务商。以下是配合使用的完整示例：

**目录结构：**

```
your-project/
├── docker-compose.yaml
└── cli-proxy-api/
    └── config.yaml
```

**docker-compose.yaml：**

```yaml
services:
  # Mihomo 代理服务
  mihomo:
    image: ghcr.io/ba0gu0/mihomo-proxy:latest
    container_name: mihomo-proxy
    ports:
      - "7890:7890"   # 代理端口 (可选对外暴露)
      - "9090:9090"   # 管理界面
    environment:
      - API_SECRET=your_secure_password
      - SUBSCRIPTION_URL=https://your-subscription-url
      - SUBSCRIPTION_INTERVAL=12
      - PROXY_MODE=rule
      - LOG_LEVEL=info
    volumes:
      - mihomo-data:/root/.config/mihomo
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-fs", "http://127.0.0.1:9090/version"]
      interval: 30s
      timeout: 10s
      retries: 3

  # CLIProxyAPI 服务
  cli-proxy-api:
    image: eceasy/cli-proxy-api:latest
    container_name: cli-proxy-api
    ports:
      - "8317:8317"   # API 主端口
    environment:
      # 通过 mihomo 容器访问代理
      - HTTP_PROXY=http://mihomo:7890
      - HTTPS_PROXY=http://mihomo:7890
      - ALL_PROXY=socks5://mihomo:7890
    volumes:
      - ./cli-proxy-api/config.yaml:/CLIProxyAPI/config.yaml
      - ./cli-proxy-api/auths:/root/.cli-proxy-api
      - ./cli-proxy-api/logs:/CLIProxyAPI/logs
    depends_on:
      mihomo:
        condition: service_healthy
    restart: unless-stopped

volumes:
  mihomo-data:
```

**cli-proxy-api/config.yaml：**

```yaml
host: ""
port: 8317

# 管理 API 设置
remote-management:
  allow-remote: false
  secret-key: "your-management-key"

# API 密钥
api-keys:
  - "your-api-key-1"
  - "your-api-key-2"

# 代理设置 - 使用 Docker 内部网络
# 注意：也可以在这里配置代理，但推荐使用环境变量方式
# proxy-url: "http://mihomo:7890"

# 请求重试设置
request-retry: 3
max-retry-interval: 30

# 日志设置
debug: false
logging-to-file: true
```

> [!TIP]
> 使用 `depends_on` 配合 `healthcheck` 确保 Mihomo 代理服务完全启动后，再启动依赖代理的服务。

### 通用 AI 应用代理模式

对于其他需要代理访问 AI 服务的应用，可以使用相同的模式：

```yaml
services:
  mihomo:
    image: ghcr.io/ba0gu0/mihomo-proxy:latest
    # ... mihomo 配置 ...

  your-ai-app:
    image: your-ai-app:latest
    environment:
      # 方式1: 通过环境变量设置代理
      - HTTP_PROXY=http://mihomo:7890
      - HTTPS_PROXY=http://mihomo:7890
    
      # 方式2: 某些应用使用特定的代理配置
      # - OPENAI_PROXY=http://mihomo:7890
      # - CURL_PROXY=http://mihomo:7890
    depends_on:
      - mihomo
```

> [!IMPORTANT]
> 确保你的订阅配置中包含可以访问 AI 服务的节点，并且规则配置正确（如 OpenAI、Anthropic 等域名走代理）。

## 📋 配置优先级

配置文件来源优先级（从高到低）：

1. **已挂载的配置文件** - 直接挂载 `config.yaml`
2. **订阅下载的配置** - 从 `SUBSCRIPTION_URL` 下载
3. **默认配置** - 使用内置的基础配置

> [!NOTE]
> 无论使用哪种配置来源，环境变量设置都会覆盖相应的配置项。

## 🔌 端口说明

| 端口     | 协议 | 用途                         |
| -------- | ---- | ---------------------------- |
| `7890` | TCP  | 混合代理端口 (HTTP + SOCKS5) |
| `9090` | HTTP | 管理 API + Yacd-meta Web UI  |

## 📂 文件结构

容器内配置目录结构：

```
/root/.config/mihomo/
├── config.yaml      # 主配置文件
├── ui/              # Yacd-meta UI 文件
├── cache.db         # 缓存数据库
├── geoip.dat        # GeoIP 数据
├── geoip.metadb     # GeoIP 元数据
└── geosite.dat      # GeoSite 数据
```

## 🛠️ 高级配置

### 使用 Host 网络模式

如果需要更好的网络性能，可以使用 host 网络模式：

```yaml
services:
  mihomo:
    image: ghcr.io/ba0gu0/mihomo-proxy:latest
    network_mode: host
    environment:
      - API_SECRET=your_password
```

### 自定义配置文件模板

参考 `config.example.yaml` 创建自定义配置：

- 支持多种代理协议: SS, VMess, Trojan, Hysteria2 等
- 支持代理提供者 (proxy-providers) 订阅
- 支持自定义规则和代理组

## 📝 许可证

[MIT License](LICENSE)

## 🔗 相关链接

- [Mihomo (Meta)](https://github.com/MetaCubeX/mihomo) - 核心代理引擎
- [Yacd-meta](https://github.com/MetaCubeX/Yacd-meta) - Web UI 管理界面
- [Mihomo Wiki](https://wiki.metacubex.one/) - 完整配置文档
