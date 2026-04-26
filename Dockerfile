# 构建 override-merge 工具
FROM golang:1.26-alpine AS override-merge-builder

WORKDIR /build

COPY subprojects/override-merge/go.mod subprojects/override-merge/go.sum ./
RUN go mod download

COPY subprojects/override-merge/cmd ./cmd
COPY subprojects/override-merge/internal ./internal

RUN CGO_ENABLED=0 GOOS=linux go build \
    -trimpath \
    -ldflags="-s -w" \
    -o /out/override-merge \
    ./cmd/override-merge

# 基于官方 Mihomo 镜像
FROM metacubex/mihomo:latest

# 安装必要工具
RUN apk add --no-cache \
    curl \
    ca-certificates \
    unzip \
    tzdata \
    yq

# 设置时区
ENV TZ=Asia/Shanghai

# 创建配置目录
RUN mkdir -p /root/.config/mihomo/ui

# 下载 Yacd-meta UI 并修改默认 API URL 为当前页面 origin
ARG YACD_VERSION=gh-pages
RUN curl -sSL \
    "https://github.com/MetaCubeX/Yacd-meta/archive/refs/heads/${YACD_VERSION}.zip" \
    -o /tmp/yacd.zip && \
    unzip -q /tmp/yacd.zip -d /tmp && \
    mv /tmp/Yacd-meta-${YACD_VERSION}/* /root/.config/mihomo/ui/ && \
    rm -rf /tmp/yacd.zip /tmp/Yacd-meta-${YACD_VERSION}
    
# 复制入口脚本
COPY entrypoint.sh /entrypoint.sh
COPY --from=override-merge-builder /out/override-merge /usr/local/bin/override-merge
RUN chmod +x /entrypoint.sh

# 环境变量默认值
# 注意: API_SECRET 不在此定义，运行时通过 -e 传入
ENV MIXED_PORT=7890 \
    ALLOW_LAN=true \
    API_PORT=9090 \
    LOG_LEVEL=info \
    PROXY_MODE=rule \
    GLOBAL_PROXY=PROXY \
    SUBSCRIPTION_PATH="" \
    SUBSCRIPTION_URL="" \
    SUBSCRIPTION_INTERVAL=24 \
    SUBSCRIPTION_RETRY_ATTEMPTS=3 \
    SUBSCRIPTION_RETRY_DELAY=3 \
    SUBSCRIPTION_OVERRIDE_FILE="" \
    SUBSCRIPTION_OVERRIDE_URL=""

# 暴露端口
EXPOSE 7890 9090

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -fs http://127.0.0.1:${API_PORT}/version || exit 1

# 入口点
ENTRYPOINT ["/entrypoint.sh"]
