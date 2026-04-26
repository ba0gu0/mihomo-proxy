package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/ba0gu0/mihomo-proxy/subprojects/override-merge/internal/override"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}

func run() error {
	var configPath string
	var overridePath string
	var overrideURL string
	var outputPath string

	flag.StringVar(&configPath, "config", "", "Path to source config YAML")
	flag.StringVar(&overridePath, "override", "", "Path to override YAML")
	flag.StringVar(&overrideURL, "override-url", "", "URL to remote override YAML")
	flag.StringVar(&outputPath, "output", "", "Write merged YAML to file instead of stdout")
	flag.Parse()

	if configPath == "" {
		return fmt.Errorf("missing required -config")
	}
	if (overridePath == "") == (overrideURL == "") {
		return fmt.Errorf("provide exactly one of -override or -override-url")
	}

	config, err := override.LoadConfigFile(configPath)
	if err != nil {
		return err
	}

	var merged map[string]any
	if overridePath != "" {
		merged, err = override.LoadOverrideFile(overridePath, config)
	} else {
		merged, err = override.LoadOverrideURL(overrideURL, config)
	}
	if err != nil {
		return err
	}
	data, err := override.EncodeYAML(merged)
	if err != nil {
		return err
	}

	if outputPath == "" {
		_, err = os.Stdout.Write(data)
		return err
	}
	return os.WriteFile(outputPath, data, 0o644)
}
