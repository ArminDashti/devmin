package serverparams

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var knownKeys = []string{
	"stack_name",
	"ssh",
	"deploy_root",
	"public_url",
}

func yamlPath(projectDir string) string {
	return filepath.Join(projectDir, ".armin", "server-scripts", "run-on-server.yaml")
}

func Read(projectDir string) (map[string]string, error) {
	path := yamlPath(projectDir)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parseFlatYAML(string(data))
}

func Write(projectDir string, values map[string]string) error {
	path := yamlPath(projectDir)
	existing, err := Read(projectDir)
	if err != nil {
		existing = map[string]string{}
	}
	for k, v := range values {
		existing[k] = v
	}
	var lines []string
	for _, key := range knownKeys {
		if val, ok := existing[key]; ok {
			lines = append(lines, fmt.Sprintf("%s: %s", key, val))
		}
	}
	for k, v := range existing {
		found := false
		for _, known := range knownKeys {
			if known == k {
				found = true
				break
			}
		}
		if !found {
			lines = append(lines, fmt.Sprintf("%s: %s", k, v))
		}
	}
	content := strings.Join(lines, "\n") + "\n"
	return os.WriteFile(path, []byte(content), 0o644)
}

func parseFlatYAML(text string) (map[string]string, error) {
	out := map[string]string{}
	for _, raw := range strings.Split(text, "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.TrimSpace(val)
		val = strings.Trim(val, `"'`)
		if key != "" {
			out[key] = val
		}
	}
	return out, nil
}
