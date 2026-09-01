package deployscripts

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/dockerstate"
	"github.com/ArminDashti/devmin-api/internal/probe"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/serverstate"
)

// FlatConfig is a simple key/value map parsed from flat YAML deploy scripts use.
type FlatConfig map[string]string

func RepoName(githubRoot string, proj discover.Project) string {
	dir := proj.PrimaryDir()
	githubRoot = filepath.Clean(githubRoot)
	dir = filepath.Clean(dir)
	rel, err := filepath.Rel(githubRoot, dir)
	if err != nil || strings.HasPrefix(rel, "..") {
		return proj.Stem
	}
	parts := strings.Split(rel, string(filepath.Separator))
	if len(parts) > 0 && parts[0] != "" && parts[0] != "." {
		return parts[0]
	}
	return proj.Stem
}

func scriptsFamily(channel runmode.Mode) (family string, ok bool) {
	switch channel {
	case runmode.Local, runmode.Server:
		return "local", true
	case runmode.LocalDocker, runmode.ServerDocker:
		return "docker", true
	default:
		return "", false
	}
}

func channelSuffix(channel runmode.Mode) (string, error) {
	switch channel {
	case runmode.Local:
		return "local", nil
	case runmode.LocalDocker:
		return "docker-local", nil
	case runmode.ServerDocker:
		return "docker-server", nil
	case runmode.Server:
		return "server", nil
	default:
		return "", fmt.Errorf("unsupported channel %q", channel)
	}
}

func actionPrefix(action string) (string, error) {
	switch action {
	case "install":
		return "install-on-", nil
	case "uninstall", "remove":
		return "remove-on-", nil
	case "update":
		return "update-on-", nil
	case "reinstall":
		return "reinstall-on-", nil
	default:
		return "", fmt.Errorf("unsupported deploy action %q", action)
	}
}

func ScriptDir(devminRoot, repoName string, channel runmode.Mode) (string, error) {
	family, ok := scriptsFamily(channel)
	if !ok {
		return "", fmt.Errorf("unsupported channel %q", channel)
	}
	return filepath.Join(devminRoot, "scripts", family, repoName), nil
}

func ScriptPath(devminRoot, repoName string, channel runmode.Mode, action string) (string, error) {
	dir, err := ScriptDir(devminRoot, repoName, channel)
	if err != nil {
		return "", err
	}
	suffix, err := channelSuffix(channel)
	if err != nil {
		return "", err
	}
	prefix, err := actionPrefix(action)
	if err != nil {
		return "", err
	}
	p := filepath.Join(dir, prefix+suffix+".ps1")
	if _, err := os.Stat(p); err != nil {
		return "", fmt.Errorf("missing deploy script %s", p)
	}
	return p, nil
}

func HasScript(devminRoot, repoName string, channel runmode.Mode, action string) bool {
	_, err := ScriptPath(devminRoot, repoName, channel, action)
	return err == nil
}

func HasChannel(devminRoot, githubRoot string, proj discover.Project, channel runmode.Mode) bool {
	repo := RepoName(githubRoot, proj)
	return HasScript(devminRoot, repo, channel, "install")
}

func ReadFlatYAML(path string) (FlatConfig, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	out := FlatConfig{}
	for _, raw := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, ":")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.Trim(strings.TrimSpace(val), `"'`)
		out[key] = val
	}
	return out, nil
}

func configPath(devminRoot, repoName string, channel runmode.Mode, action string) (string, error) {
	dir, err := ScriptDir(devminRoot, repoName, channel)
	if err != nil {
		return "", err
	}
	suffix, err := channelSuffix(channel)
	if err != nil {
		return "", err
	}
	prefix, err := actionPrefix(action)
	if err != nil {
		return "", err
	}
	return filepath.Join(dir, prefix+suffix+".yaml"), nil
}

func ReadConfig(devminRoot, repoName string, channel runmode.Mode, action string) (FlatConfig, error) {
	for _, act := range []string{action, "install"} {
		path, err := configPath(devminRoot, repoName, channel, act)
		if err != nil {
			continue
		}
		cfg, err := ReadFlatYAML(path)
		if err == nil {
			return cfg, nil
		}
	}
	return nil, fmt.Errorf("no deploy yaml for %s/%s", repoName, channel)
}

func ConfigInt(cfg FlatConfig, key string) int {
	raw := strings.TrimSpace(cfg[key])
	if raw == "" {
		return 0
	}
	n, err := strconv.Atoi(raw)
	if err != nil {
		return 0
	}
	return n
}

func StackName(cfg FlatConfig, fallback string) string {
	if v := strings.TrimSpace(cfg["stack_name"]); v != "" {
		return v
	}
	return fallback
}

func OnLocalDocker(cfg FlatConfig, projects map[string]bool, stem string) bool {
	stack := StackName(cfg, stem)
	if projects[stack] {
		return true
	}
	return dockerstate.OnDocker(stem, stack, "", projects)
}

func LocalDockerPorts(cfg FlatConfig, fallbackAPI, fallbackWebUI int) (apiPort, webuiPort int) {
	apiPort = ConfigInt(cfg, "internal_port")
	webuiPort = ConfigInt(cfg, "publish_port")
	if apiPort == 0 {
		apiPort = fallbackAPI
	}
	if webuiPort == 0 {
		webuiPort = fallbackWebUI
	}
	return apiPort, webuiPort
}

func OnLocalNative(cfg FlatConfig) bool {
	apiPort, webuiPort := LocalDockerPorts(cfg, 0, 0)
	if apiPort > 0 && probe.PortListening("127.0.0.1", apiPort) {
		return true
	}
	if webuiPort > 0 && probe.PortListening("127.0.0.1", webuiPort) {
		return true
	}
	return false
}

func ServerDockerDeployConfig(cfg FlatConfig) (*serverstate.DeployConfig, bool) {
	stack := strings.TrimSpace(cfg["stack_name"])
	ssh := strings.TrimSpace(cfg["ssh"])
	volume := strings.TrimSpace(cfg["volume_dir"])
	if stack == "" || ssh == "" {
		return nil, false
	}
	return &serverstate.DeployConfig{
		StackName:   stack,
		SSH:         ssh,
		VolumeDir:   volume,
		ComposeFile: cfg["compose_file"],
		InternalPort: cfg["internal_port"],
	}, true
}

func BareServerDeployConfig(cfg FlatConfig) (*serverstate.BareDeployConfig, bool) {
	stack := strings.TrimSpace(cfg["stack_name"])
	ssh := strings.TrimSpace(cfg["ssh"])
	if stack == "" || ssh == "" {
		return nil, false
	}
	pub := strings.TrimSpace(cfg["public_url"])
	if pub == "" {
		domain := strings.TrimSpace(cfg["domain"])
		if domain != "" {
			pub = "https://" + strings.TrimSuffix(domain, "/") + "/"
		}
	}
	return &serverstate.BareDeployConfig{
		StackName:  stack,
		SSH:        ssh,
		DeployRoot: cfg["deploy_root"],
		PublicURL:  pub,
	}, true
}
