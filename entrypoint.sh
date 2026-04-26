#!/bin/sh
set -e

CONFIG_DIR="/root/.config/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
UI_DIR="${CONFIG_DIR}/ui"

# 默认值
MIXED_PORT="${MIXED_PORT:-7890}"
ALLOW_LAN="${ALLOW_LAN:-true}"
API_PORT="${API_PORT:-9090}"
API_SECRET="${API_SECRET:-}"
LOG_LEVEL="${LOG_LEVEL:-info}"
PROXY_MODE="${PROXY_MODE:-rule}"
GLOBAL_PROXY="${GLOBAL_PROXY:-PROXY}"
SUBSCRIPTION_PATH="${SUBSCRIPTION_PATH:-}"
SUBSCRIPTION_URL="${SUBSCRIPTION_URL:-}"
SUBSCRIPTION_INTERVAL="${SUBSCRIPTION_INTERVAL:-24}"
SUBSCRIPTION_RETRY_ATTEMPTS="${SUBSCRIPTION_RETRY_ATTEMPTS:-3}"
SUBSCRIPTION_RETRY_DELAY="${SUBSCRIPTION_RETRY_DELAY:-3}"
SUBSCRIPTION_OVERRIDE_FILE="${SUBSCRIPTION_OVERRIDE_FILE:-}"
SUBSCRIPTION_OVERRIDE_URL="${SUBSCRIPTION_OVERRIDE_URL:-}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

is_unsigned_integer() {
    case "$1" in
        ''|*[!0-9]*)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

has_subscription_source() {
    [ -n "$SUBSCRIPTION_PATH" ] || [ -n "$SUBSCRIPTION_URL" ]
}

has_subscription_override() {
    [ -n "$SUBSCRIPTION_OVERRIDE_FILE" ] || [ -n "$SUBSCRIPTION_OVERRIDE_URL" ]
}

copy_subscription_file() {
    if [ ! -f "$SUBSCRIPTION_PATH" ]; then
        log "订阅文件不存在: ${SUBSCRIPTION_PATH}"
        return 1
    fi

    log "正在读取订阅文件: ${SUBSCRIPTION_PATH}"
    if ! cp "$SUBSCRIPTION_PATH" "${CONFIG_FILE}.tmp"; then
        log "订阅文件复制失败"
        rm -f "${CONFIG_FILE}.tmp"
        return 1
    fi
    if ! mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"; then
        log "订阅文件写入失败"
        rm -f "${CONFIG_FILE}.tmp"
        return 1
    fi
    log "订阅文件读取成功"
}

download_subscription() {
    if [ -z "$SUBSCRIPTION_URL" ]; then
        return 1
    fi

    if ! is_unsigned_integer "$SUBSCRIPTION_RETRY_ATTEMPTS" ||
        ! is_unsigned_integer "$SUBSCRIPTION_RETRY_DELAY"; then
        log "订阅重试参数无效，改用默认值"
        SUBSCRIPTION_RETRY_ATTEMPTS=3
        SUBSCRIPTION_RETRY_DELAY=3
    fi

    attempts="$SUBSCRIPTION_RETRY_ATTEMPTS"
    if [ "$attempts" -lt 1 ]; then
        attempts=1
    fi

    current=1
    while [ "$current" -le "$attempts" ]; do
        log "正在下载订阅配置... (${current}/${attempts})"
        if curl -fsSL \
            -A "clash-verge/v1.7.7" \
            -o "${CONFIG_FILE}.tmp" \
            "$SUBSCRIPTION_URL"; then
            if ! mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"; then
                log "订阅配置落盘失败"
                rm -f "${CONFIG_FILE}.tmp"
                return 1
            fi
            log "订阅配置下载成功"
            return 0
        fi

        rm -f "${CONFIG_FILE}.tmp"
        if [ "$current" -lt "$attempts" ]; then
            log "订阅配置下载失败，${SUBSCRIPTION_RETRY_DELAY}秒后重试"
            sleep "$SUBSCRIPTION_RETRY_DELAY"
        fi
        current=$((current + 1))
    done

    log "订阅配置下载失败，已达到最大重试次数"
    return 1
}

apply_subscription_override() {
    if [ -n "$SUBSCRIPTION_OVERRIDE_FILE" ]; then
        if [ ! -f "$SUBSCRIPTION_OVERRIDE_FILE" ]; then
            log "override 文件不存在: ${SUBSCRIPTION_OVERRIDE_FILE}"
            return 1
        fi

        log "应用 override 文件: ${SUBSCRIPTION_OVERRIDE_FILE}"
        if ! /usr/local/bin/override-merge \
            -config "$CONFIG_FILE" \
            -override "$SUBSCRIPTION_OVERRIDE_FILE" \
            -output "${CONFIG_FILE}.merged"; then
            rm -f "${CONFIG_FILE}.merged"
            return 1
        fi
        if ! mv "${CONFIG_FILE}.merged" "$CONFIG_FILE"; then
            rm -f "${CONFIG_FILE}.merged"
            return 1
        fi
        return 0
    fi

    if [ -n "$SUBSCRIPTION_OVERRIDE_URL" ]; then
        log "应用 override 地址: ${SUBSCRIPTION_OVERRIDE_URL}"
        if ! /usr/local/bin/override-merge \
            -config "$CONFIG_FILE" \
            -override-url "$SUBSCRIPTION_OVERRIDE_URL" \
            -output "${CONFIG_FILE}.merged"; then
            rm -f "${CONFIG_FILE}.merged"
            return 1
        fi
        if ! mv "${CONFIG_FILE}.merged" "$CONFIG_FILE"; then
            rm -f "${CONFIG_FILE}.merged"
            return 1
        fi
        return 0
    fi

    return 0
}

refresh_subscription_config() {
    if [ -n "$SUBSCRIPTION_PATH" ]; then
        copy_subscription_file || return 1
    elif [ -n "$SUBSCRIPTION_URL" ]; then
        download_subscription || return 1
    else
        return 1
    fi

    apply_subscription_override || return 1
}

# 生成默认配置
generate_default_config() {
    log "生成默认配置..."
    cat > "$CONFIG_FILE" << EOF
# Mihomo 默认配置
mixed-port: ${MIXED_PORT}
allow-lan: ${ALLOW_LAN}
mode: ${PROXY_MODE}
log-level: ${LOG_LEVEL}

# DNS 配置
dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 223.5.5.5
    - 119.29.29.29
  fallback:
    - 8.8.8.8
    - 1.1.1.1

# 代理组
proxy-groups:
  - name: "PROXY"
    type: select
    proxies:
      - DIRECT

# 规则
rules:
  - MATCH,DIRECT
EOF
}

# 应用环境变量覆盖配置
apply_env_overrides() {
    log "应用环境变量覆盖..."
    
    # 基本配置
    yq -i ".mixed-port = ${MIXED_PORT}" "$CONFIG_FILE"
    yq -i ".allow-lan = ${ALLOW_LAN}" "$CONFIG_FILE"
    yq -i ".mode = \"${PROXY_MODE}\"" "$CONFIG_FILE"
    yq -i ".log-level = \"${LOG_LEVEL}\"" "$CONFIG_FILE"
    
    # 移除可能冲突的端口配置，统一使用 mixed-port
    yq -i "del(.port)" "$CONFIG_FILE"
    yq -i "del(.socks-port)" "$CONFIG_FILE"
    
    # 管理接口配置
    if [ -n "$API_SECRET" ]; then
        yq -i ".external-controller = \"0.0.0.0:${API_PORT}\"" "$CONFIG_FILE"
        yq -i ".secret = \"${API_SECRET}\"" "$CONFIG_FILE"
        yq -i ".external-ui = \"${UI_DIR}\"" "$CONFIG_FILE"
        log "管理接口已启用: 0.0.0.0:${API_PORT}"
    else
        # 移除管理接口配置
        yq -i "del(.external-controller)" "$CONFIG_FILE"
        yq -i "del(.secret)" "$CONFIG_FILE"
        yq -i "del(.external-ui)" "$CONFIG_FILE"
        log "管理接口未启用 (未设置 API_SECRET)"
    fi
}

# 设置全局代理选择 (需要在 mihomo 启动后调用)
set_global_proxy() {
    if [ -n "$API_SECRET" ] && [ -n "$GLOBAL_PROXY" ]; then
        log "设置全局代理: GLOBAL -> ${GLOBAL_PROXY}"
        # 等待 mihomo 启动
        sleep 2
        # 设置 GLOBAL 代理组选中具体的代理节点
        curl -s -X PUT "http://127.0.0.1:${API_PORT}/proxies/GLOBAL" \
            -H "Authorization: Bearer ${API_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{\"name\":\"${GLOBAL_PROXY}\"}" || log "设置全局代理失败 (可能代理节点不存在)"
    fi
}

# 订阅定时更新
start_subscription_updater() {
    if has_subscription_source; then
        log "启动订阅定时更新 (间隔: ${SUBSCRIPTION_INTERVAL}小时)"
        (
            while true; do
                sleep $((SUBSCRIPTION_INTERVAL * 3600))
                log "定时更新订阅..."
                if refresh_subscription_config; then
                    apply_env_overrides
                    # 通知 mihomo 重载配置
                    if [ -n "$API_SECRET" ]; then
                        curl -s -X PUT "http://127.0.0.1:${API_PORT}/configs" \
                            -H "Authorization: Bearer ${API_SECRET}" \
                            -H "Content-Type: application/json" \
                            -d '{"path":"'"$CONFIG_FILE"'"}' || true
                        log "配置重载请求已发送"
                    fi
                fi
            done
        ) &
    fi
}

# 主流程
main() {
    log "=== Mihomo Proxy Container 启动 ==="
    
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR"

    if ! is_unsigned_integer "$SUBSCRIPTION_INTERVAL" ||
        [ "$SUBSCRIPTION_INTERVAL" -lt 1 ]; then
        log "订阅更新间隔无效，改用 24 小时"
        SUBSCRIPTION_INTERVAL=24
    fi

    if [ -n "$SUBSCRIPTION_PATH" ] && [ -n "$SUBSCRIPTION_URL" ]; then
        log "同时配置了 SUBSCRIPTION_PATH 和 SUBSCRIPTION_URL，优先使用本地文件"
    fi

    if [ -n "$SUBSCRIPTION_OVERRIDE_FILE" ] && [ -n "$SUBSCRIPTION_OVERRIDE_URL" ]; then
        log "同时配置了 SUBSCRIPTION_OVERRIDE_FILE 和 SUBSCRIPTION_OVERRIDE_URL，优先使用本地 override 文件"
    fi
    
    # 配置文件处理优先级：
    # 1. 已挂载的配置文件
    # 2. 订阅下载的配置
    # 3. 默认配置
    
    if has_subscription_source; then
        if refresh_subscription_config; then
            log "使用订阅源生成配置"
        elif [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
            log "订阅源刷新失败，回退到已存在的配置文件"
        else
            log "订阅源刷新失败，回退到默认配置"
            generate_default_config
        fi
    elif [ -f "$CONFIG_FILE" ] && [ -s "$CONFIG_FILE" ]; then
        log "使用已存在的配置文件"
    else
        generate_default_config
    fi
    
    # 应用环境变量覆盖
    apply_env_overrides
    
    # 显示配置摘要
    log "配置摘要:"
    log "  - 混合代理端口: ${MIXED_PORT}"
    log "  - 允许局域网: ${ALLOW_LAN}"
    log "  - 代理模式: ${PROXY_MODE}"
    log "  - 日志级别: ${LOG_LEVEL}"
    if [ -n "$API_SECRET" ]; then
        log "  - 管理端口: ${API_PORT}"
        log "  - UI 路径: ${UI_DIR}"
        log "  - 全局代理组: ${GLOBAL_PROXY}"
    fi
    if has_subscription_source; then
        log "  - 订阅更新间隔: ${SUBSCRIPTION_INTERVAL}小时"
    fi
    if [ -n "$SUBSCRIPTION_PATH" ]; then
        log "  - 订阅文件路径: ${SUBSCRIPTION_PATH}"
    fi
    if [ -n "$SUBSCRIPTION_URL" ]; then
        log "  - 订阅地址: ${SUBSCRIPTION_URL}"
    fi
    if has_subscription_override; then
        log "  - override: 已启用"
    fi
    
    # 启动订阅更新器
    start_subscription_updater
    
    # 后台设置全局代理 (需要等待 mihomo 启动)
    set_global_proxy &
    
    log "启动 Mihomo..."
    exec /mihomo -d "$CONFIG_DIR"
}

main "$@"
