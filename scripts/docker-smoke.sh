#!/bin/sh
set -eu

PROJECT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
IMAGE_TAG="mihomo-proxy:smoke"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

log() {
    printf '[docker-smoke] %s\n' "$1"
}

write_fixtures() {
    cat > "${TMP_DIR}/subscription.yaml" <<'EOF'
rules:
  - MATCH,PROXY
dns:
  enable: true
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
EOF

    cat > "${TMP_DIR}/override.yaml" <<'EOF'
+rules:
  - DOMAIN-SUFFIX,baidu.com,DIRECT
dns!:
  enable: false
EOF

    cat > "${TMP_DIR}/override.js" <<'EOF'
function main(config) {
  config.rules = ["MATCH,DIRECT"];
  config["proxy-groups"] = [
    { name: "AUTO", type: "url-test", "include-all": true },
  ];
  return config;
}
EOF

    cat > "${TMP_DIR}/fake-mihomo" <<'EOF'
#!/bin/sh
set -eu

config_dir=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        -d)
            config_dir="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

config_file="${config_dir}/config.yaml"
if [ ! -f "$config_file" ]; then
    echo "missing config: $config_file" >&2
    exit 1
fi

if [ -n "${EXPECT_RULE:-}" ] && ! grep -Fq "$EXPECT_RULE" "$config_file"; then
    echo "missing rule: $EXPECT_RULE" >&2
    cat "$config_file" >&2
    exit 1
fi

if [ -n "${EXPECT_GROUP:-}" ] && ! grep -Fq "$EXPECT_GROUP" "$config_file"; then
    echo "missing group: $EXPECT_GROUP" >&2
    cat "$config_file" >&2
    exit 1
fi
EOF
    chmod +x "${TMP_DIR}/fake-mihomo"
}

build_image() {
    log "building image"
    docker build -t "$IMAGE_TAG" "$PROJECT_DIR" >/dev/null
}

run_case() {
    name="$1"
    override_host="$2"
    override_container="$3"
    expect_rule="${4:-}"
    expect_group="${5:-}"

    log "running ${name} case"
    docker run --rm \
        -v "${TMP_DIR}/subscription.yaml:/subscriptions/profile.yaml:ro" \
        -v "${override_host}:${override_container}:ro" \
        -v "${TMP_DIR}/fake-mihomo:/mihomo:ro" \
        -e SUBSCRIPTION_PATH=/subscriptions/profile.yaml \
        -e SUBSCRIPTION_OVERRIDE_FILE="$override_container" \
        -e EXPECT_RULE="$expect_rule" \
        -e EXPECT_GROUP="$expect_group" \
        "$IMAGE_TAG" >/dev/null
}

main() {
    write_fixtures
    build_image
    run_case "yaml override" "${TMP_DIR}/override.yaml" /overrides/override.yaml \
        "DOMAIN-SUFFIX,baidu.com,DIRECT" "enable: false"
    run_case "js override" "${TMP_DIR}/override.js" /overrides/override.js \
        "MATCH,DIRECT" "name: AUTO"
    log "all docker smoke tests passed"
}

main "$@"
