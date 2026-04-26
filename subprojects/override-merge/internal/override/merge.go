package override

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/dop251/goja"
	"gopkg.in/yaml.v3"
)

const defaultTimeout = 20 * time.Second

func LoadConfigFile(path string) (map[string]any, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read config %s: %w", path, err)
	}
	return LoadConfig(data)
}

func LoadOverrideFile(path string, config map[string]any) (map[string]any, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read override %s: %w", path, err)
	}
	return ApplyOverride(config, path, data)
}

func LoadOverrideURL(url string, config map[string]any) (map[string]any, error) {
	client := &http.Client{Timeout: defaultTimeout}
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("build override request: %w", err)
	}
	req.Header.Set("User-Agent", "mihomo-proxy-override-merge")

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetch override %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return nil, fmt.Errorf("fetch override %s: unexpected status %s", url, resp.Status)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("read override response %s: %w", url, err)
	}
	return ApplyOverride(config, url, data)
}

func LoadConfig(data []byte) (map[string]any, error) {
	return unmarshalYAML(data, "config")
}

func LoadOverride(data []byte) (map[string]any, error) {
	return unmarshalYAML(data, "override")
}

func Merge(config map[string]any, ov map[string]any) map[string]any {
	target := cloneMap(config)
	mergeInto(target, ov)
	return target
}

func ApplyOverride(config map[string]any, source string, data []byte) (map[string]any, error) {
	if isJS(source) {
		return applyJSOverride(config, source, data)
	}

	override, err := LoadOverride(data)
	if err != nil {
		return nil, err
	}
	return Merge(config, override), nil
}

func EncodeYAML(value map[string]any) ([]byte, error) {
	data, err := yaml.Marshal(value)
	if err != nil {
		return nil, fmt.Errorf("marshal merged config: %w", err)
	}
	return data, nil
}

func unmarshalYAML(data []byte, label string) (map[string]any, error) {
	decoder := yaml.NewDecoder(bytes.NewReader(data))
	decoder.KnownFields(false)

	var value map[string]any
	if err := decoder.Decode(&value); err != nil {
		return nil, fmt.Errorf("parse %s yaml: %w", label, err)
	}
	if value == nil {
		return map[string]any{}, nil
	}
	return value, nil
}

func mergeInto(target map[string]any, ov map[string]any) {
	for rawKey, overrideValue := range ov {
		key, arrayMode, forceReplace := parseKey(rawKey)
		currentValue, hasCurrent := target[key]

		if nestedOverride, ok := asMap(overrideValue); ok {
			if !forceReplace {
				if nestedCurrent, ok := asMap(currentValue); ok {
					mergeInto(nestedCurrent, nestedOverride)
					target[key] = nestedCurrent
					continue
				}
			}
			target[key] = cloneMap(nestedOverride)
			continue
		}

		if overrideArray, ok := asSlice(overrideValue); ok {
			target[key] = mergeArray(currentValue, overrideArray, arrayMode, hasCurrent)
			continue
		}

		target[key] = overrideValue
	}
}

func applyJSOverride(config map[string]any, source string, data []byte) (map[string]any, error) {
	vm := goja.New()

	if _, err := vm.RunString(string(data)); err != nil {
		return nil, fmt.Errorf("parse js override %s: %w", source, err)
	}

	mainValue := vm.Get("main")
	mainFn, ok := goja.AssertFunction(mainValue)
	if !ok {
		return nil, fmt.Errorf("js override %s must define function main(config)", source)
	}

	input := cloneMap(config)
	result, err := mainFn(goja.Undefined(), vm.ToValue(input))
	if err != nil {
		return nil, fmt.Errorf("execute js override %s: %w", source, err)
	}

	exported := result.Export()
	if exported == nil {
		return input, nil
	}

	merged, ok := exported.(map[string]any)
	if !ok {
		return nil, fmt.Errorf("js override %s must return an object", source)
	}
	return merged, nil
}

func mergeArray(currentValue any, overrideValue []any, mode string, hasCurrent bool) []any {
	if mode == "replace" {
		return cloneSlice(overrideValue)
	}

	currentArray, ok := asSlice(currentValue)
	if !ok || !hasCurrent {
		currentArray = []any{}
	}

	if mode == "prepend" {
		return append(cloneSlice(overrideValue), cloneSlice(currentArray)...)
	}
	return append(cloneSlice(currentArray), cloneSlice(overrideValue)...)
}

func parseKey(rawKey string) (string, string, bool) {
	key := rawKey
	arrayMode := "replace"
	forceReplace := false

	if strings.HasPrefix(key, "+") {
		arrayMode = "prepend"
		key = key[1:]
	} else if strings.HasSuffix(key, "+") {
		arrayMode = "append"
		key = key[:len(key)-1]
	}

	if strings.HasSuffix(key, "!") {
		forceReplace = true
		key = key[:len(key)-1]
	}

	if strings.HasPrefix(key, "<") && strings.HasSuffix(key, ">") && len(key) > 2 {
		key = key[1 : len(key)-1]
	}
	return key, arrayMode, forceReplace
}

func isJS(source string) bool {
	switch strings.ToLower(filepath.Ext(source)) {
	case ".js", ".mjs", ".cjs":
		return true
	default:
		return false
	}
}

func asMap(value any) (map[string]any, bool) {
	item, ok := value.(map[string]any)
	return item, ok
}

func asSlice(value any) ([]any, bool) {
	item, ok := value.([]any)
	return item, ok
}

func cloneMap(value map[string]any) map[string]any {
	out := make(map[string]any, len(value))
	for key, item := range value {
		switch nested := item.(type) {
		case map[string]any:
			out[key] = cloneMap(nested)
		case []any:
			out[key] = cloneSlice(nested)
		default:
			out[key] = item
		}
	}
	return out
}

func cloneSlice(value []any) []any {
	out := make([]any, 0, len(value))
	for _, item := range value {
		switch nested := item.(type) {
		case map[string]any:
			out = append(out, cloneMap(nested))
		case []any:
			out = append(out, cloneSlice(nested))
		default:
			out = append(out, item)
		}
	}
	return out
}
