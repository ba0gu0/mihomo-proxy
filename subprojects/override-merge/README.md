# override-merge

一个独立的 Go 子项目，用来实现 Mihomo YAML override 合并逻辑。

当前目标：

- 读取原始订阅配置 YAML
- 读取本地或远程 override YAML / JS
- 按 override-hub / Mihomo Purity 的语义处理
- 输出合并后的 YAML

支持的键语义：

- `+rules`: 数组前置
- `rules+`: 数组追加
- `dns!`: 强制替换对象
- `<proxy-groups>`: 去掉尖括号后按原键名合并

JS 支持：

- 识别 `.js` / `.mjs` / `.cjs`
- 执行 `main(config)` 形式的 override 脚本
- 最终输出仍然是 YAML

## 运行

```bash
cd subprojects/override-merge
go run ./cmd/override-merge \
  -config /path/to/config.yaml \
  -override /path/to/override.yaml
```

使用 JS override：

```bash
cd subprojects/override-merge
go run ./cmd/override-merge \
  -config /path/to/config.yaml \
  -override /path/to/override.js
```

使用远程 override：

```bash
cd subprojects/override-merge
go run ./cmd/override-merge \
  -config /path/to/config.yaml \
  -override-url 'https://raw.githubusercontent.com/.../override.yaml'
```

写入输出文件：

```bash
cd subprojects/override-merge
go run ./cmd/override-merge \
  -config /path/to/config.yaml \
  -override /path/to/override.yaml \
  -output /path/to/output.yaml
```

## 测试

```bash
cd subprojects/override-merge
go test ./...
```

完整测试入口：

```bash
cd subprojects/override-merge
./scripts/test.sh
```

如果要带真实远程 raw 地址做 smoke：

```bash
cd subprojects/override-merge
REMOTE_OVERRIDE_URL='https://raw.githubusercontent.com/.../override.yaml' \
  ./scripts/test.sh
```
