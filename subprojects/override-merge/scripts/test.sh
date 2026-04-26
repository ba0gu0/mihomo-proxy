#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT INT TERM

log() {
    printf '[override-merge:test] %s\n' "$1"
}

write_fixtures() {
    cat > "${TMP_DIR}/config.yaml" <<'EOF'
rules:
  - MATCH,PROXY
dns:
  enable: true
  nameserver:
    - 1.1.1.1
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
}

run_local_smoke() {
    log "running local CLI smoke test"
    write_fixtures
    output="$(
        cd "${PROJECT_DIR}" &&
        go run ./cmd/override-merge \
            -config "${TMP_DIR}/config.yaml" \
            -override "${TMP_DIR}/override.yaml"
    )"
    printf '%s\n' "$output" | grep -q 'DOMAIN-SUFFIX,baidu.com,DIRECT'
    printf '%s\n' "$output" | grep -q 'enable: false'
}

run_remote_smoke() {
    if [ -z "${REMOTE_OVERRIDE_URL:-}" ]; then
        log "skipping remote smoke test"
        return 0
    fi

    log "running remote override smoke test"
    write_fixtures
    output="$(
        cd "${PROJECT_DIR}" &&
        go run ./cmd/override-merge \
            -config "${TMP_DIR}/config.yaml" \
            -override-url "${REMOTE_OVERRIDE_URL}"
    )"
    printf '%s\n' "$output" | grep -q 'proxy-groups:'
}

run_js_smoke() {
    log "running local JS smoke test"
    write_fixtures
    output="$(
        cd "${PROJECT_DIR}" &&
        go run ./cmd/override-merge \
            -config "${TMP_DIR}/config.yaml" \
            -override "${TMP_DIR}/override.js"
    )"
    printf '%s\n' "$output" | grep -q 'MATCH,DIRECT'
    printf '%s\n' "$output" | grep -q 'name: AUTO'
}

main() {
    log "running go test"
    (
        cd "${PROJECT_DIR}"
        go test ./...
    )
    run_local_smoke
    run_js_smoke
    run_remote_smoke
    log "all tests passed"
}

main "$@"
