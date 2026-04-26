package override

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestMergeArrayModesAndForceReplace(t *testing.T) {
	config, err := LoadConfig([]byte(`
rules:
  - MATCH,PROXY
dns:
  enable: true
  nameserver:
    - 1.1.1.1
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
`))
	if err != nil {
		t.Fatalf("load config: %v", err)
	}

	ov, err := LoadOverride([]byte(`
+rules:
  - DOMAIN-SUFFIX,baidu.com,DIRECT
rules+:
  - DOMAIN-SUFFIX,google.com,PROXY
dns!:
  enable: false
<proxy-groups>:
  - name: AUTO
    type: url-test
    include-all: true
`))
	if err != nil {
		t.Fatalf("load override: %v", err)
	}

	got := Merge(config, ov)
	rules := got["rules"].([]any)
	if rules[0] != "DOMAIN-SUFFIX,baidu.com,DIRECT" {
		t.Fatalf("prepend rules mismatch: %#v", rules)
	}
	if rules[2] != "DOMAIN-SUFFIX,google.com,PROXY" {
		t.Fatalf("append rules mismatch: %#v", rules)
	}

	dns := got["dns"].(map[string]any)
	if dns["enable"] != false {
		t.Fatalf("force replace dns mismatch: %#v", dns)
	}

	groups := got["proxy-groups"].([]any)
	firstGroup := groups[0].(map[string]any)
	if firstGroup["name"] != "AUTO" {
		t.Fatalf("wrapped key merge mismatch: %#v", groups)
	}
}

func TestLoadOverrideURL(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("rules:\n  - MATCH,PROXY\n"))
	}))
	defer server.Close()

	ov, err := LoadOverrideURL(server.URL, map[string]any{})
	if err != nil {
		t.Fatalf("load override url: %v", err)
	}

	rules := ov["rules"].([]any)
	if len(rules) != 1 || rules[0] != "MATCH,PROXY" {
		t.Fatalf("unexpected override rules: %#v", rules)
	}
}

func TestApplyJSOverride(t *testing.T) {
	config, err := LoadConfig([]byte(`
rules:
  - MATCH,PROXY
proxy-groups:
  - name: PROXY
    type: select
    proxies:
      - DIRECT
`))
	if err != nil {
		t.Fatalf("load config: %v", err)
	}

	got, err := ApplyOverride(config, "override.js", []byte(`
function main(config) {
  config.rules = ["MATCH,DIRECT"];
  config["proxy-groups"] = [
    { name: "AUTO", type: "url-test", "include-all": true },
  ];
  return config;
}
`))
	if err != nil {
		t.Fatalf("apply js override: %v", err)
	}

	rules := got["rules"].([]any)
	if len(rules) != 1 || rules[0] != "MATCH,DIRECT" {
		t.Fatalf("js rules mismatch: %#v", rules)
	}

	groups := got["proxy-groups"].([]any)
	firstGroup := groups[0].(map[string]any)
	if firstGroup["name"] != "AUTO" {
		t.Fatalf("js groups mismatch: %#v", groups)
	}
}
