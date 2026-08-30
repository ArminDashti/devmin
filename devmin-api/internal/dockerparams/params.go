package dockerparams

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

var knownKeys = []string{
	"stack_name",
	"image_tag",
	"compose_file",
	"dockerfile",
	"docker_network",
	"internal_port",
	"publish_port",
	"delete_volume",
	"delete_image",
}

type Target string

const (
	TargetLocal  Target = "local"
	TargetServer Target = "server"
)

func ParseTarget(raw string) (Target, error) {
	t := Target(strings.TrimSpace(raw))
	switch t {
	case TargetLocal, TargetServer:
		return t, nil
	default:
		return "", fmt.Errorf("target must be local or server")
	}
}

func yamlPath(projectDir string, target Target) string {
	name := "run-on-docker-local.yaml"
	if target == TargetServer {
		name = "run-on-docker-server.yaml"
	}
	return filepath.Join(projectDir, ".armin", "docker-scripts", name)
}

func Read(projectDir string, target Target) (map[string]string, error) {
	path := yamlPath(projectDir, target)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	return parseFlatYAML(string(data))
}

func Write(projectDir string, target Target, values map[string]string) error {
	path := yamlPath(projectDir, target)
	existing, err := Read(projectDir, target)
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
