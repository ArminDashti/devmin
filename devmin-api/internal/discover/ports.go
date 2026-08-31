package discover

import (
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

var (
	internalPortEnvRe = regexp.MustCompile(`INTERNAL_PORT:-(\d+)`)
	exposePortRe      = regexp.MustCompile(`(?m)^\s*-\s*"(\d+)"\s*$`)
	hostContainerRe   = regexp.MustCompile(`(?m)^\s*-\s*"(\d+):(\d+)"`)
)

const postgresContainerPort = 5432

func resolveInternalPort(projectDir string, fallback int) int {
	if projectDir == "" {
		return fallback
	}
	if n := yamlInternalPort(projectDir); n > 0 {
		return n
	}
	if n := composeInternalPort(findBaseCompose(projectDir)); n > 0 {
		return n
	}
	return fallback
}

// ResolvePublishPort reads the host publish port from run-on-docker-local.yaml.
func ResolvePublishPort(projectDir string) int {
	return yamlPortField(projectDir, "publish_port")
}

func yamlInternalPort(projectDir string) int {
	return yamlPortField(projectDir, "internal_port")
}

func yamlPortField(projectDir, field string) int {
	yamlPath := filepath.Join(projectDir, ".armin", "docker-scripts", "run-on-docker-local.yaml")
	data, err := os.ReadFile(yamlPath)
	if err != nil {
		return 0
	}
	prefix := field + ":"
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, prefix) {
			continue
		}
		val := strings.TrimSpace(strings.TrimPrefix(line, prefix))
		val = strings.Trim(val, `"'`)
		n, err := strconv.Atoi(val)
		if err != nil || n <= 0 {
			return 0
		}
		return n
	}
	return 0
}

func composeInternalPort(composePath string) int {
	if composePath == "" {
		return 0
	}
	data, err := os.ReadFile(composePath)
	if err != nil {
		return 0
	}
	text := string(data)
	if loc := internalPortEnvRe.FindStringSubmatch(text); len(loc) == 2 {
		if n := atoiPort(loc[1]); n > 0 && n != postgresContainerPort {
			return n
		}
	}
	for _, m := range exposePortRe.FindAllStringSubmatch(text, -1) {
		if n := atoiPort(m[1]); n > 0 && n != postgresContainerPort {
			return n
		}
	}
	for _, m := range hostContainerRe.FindAllStringSubmatch(text, -1) {
		if n := atoiPort(m[2]); n > 0 && n != postgresContainerPort {
			return n
		}
	}
	return 0
}

func atoiPort(raw string) int {
	n, err := strconv.Atoi(raw)
	if err != nil {
		return 0
	}
	return n
}
