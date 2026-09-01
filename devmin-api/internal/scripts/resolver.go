package scripts

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/deployscripts"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/serverstate"
)

type Action string

const (
	ActionEnable    Action = "enable"
	ActionDisable   Action = "disable"
	ActionInstall   Action = "install"
	ActionUninstall Action = "uninstall"
	ActionUpdate    Action = "update"
	ActionReinstall Action = "reinstall"
)

func ParseAction(raw string) (Action, error) {
	a := Action(raw)
	switch a {
	case ActionEnable, ActionDisable, ActionInstall, ActionUninstall, ActionUpdate, ActionReinstall:
		return a, nil
	default:
		return "", fmt.Errorf("invalid action %q", raw)
	}
}

type Resolver struct {
	cfg config.Config
}

func NewResolver(cfg config.Config) *Resolver {
	return &Resolver{cfg: cfg}
}

func (r *Resolver) ProjectDir(proj discover.Project, app *discover.Application) string {
	if app != nil && app.Dir != "" {
		return app.Dir
	}
	return proj.PrimaryDir()
}

func (r *Resolver) ScriptPath(channel runmode.Mode, action Action, proj discover.Project) (string, error) {
	if isDeployAction(action) {
		repo := deployscripts.RepoName(r.cfg.GitHubRoot, proj)
		path, err := deployscripts.ScriptPath(r.cfg.DevminRoot, repo, channel, string(action))
		if err == nil {
			return path, nil
		}
		return "", err
	}

	projectDir := proj.PrimaryDir()
	switch channel {
	case runmode.Local:
		if r.cfg.NativeRunnerScript == "" {
			return "", fmt.Errorf("native runner script not configured")
		}
		return r.cfg.NativeRunnerScript, nil
	case runmode.LocalDocker:
		p := legacyDockerLocalScript(projectDir)
		if _, err := os.Stat(p); err != nil {
			return "", fmt.Errorf("missing %s", p)
		}
		return p, nil
	case runmode.ServerDocker:
		p := serverstate.ScriptPath(projectDir)
		if _, err := os.Stat(p); err != nil {
			return "", fmt.Errorf("missing server docker script for %s", projectDir)
		}
		return p, nil
	case runmode.Server:
		p := serverstate.BareServerScriptPath(projectDir)
		if _, err := os.Stat(p); err != nil {
			return "", fmt.Errorf("missing server script for %s", projectDir)
		}
		return p, nil
	default:
		return "", fmt.Errorf("unknown channel %q", channel)
	}
}

func isDeployAction(action Action) bool {
	switch action {
	case ActionInstall, ActionUninstall, ActionUpdate, ActionReinstall:
		return true
	default:
		return false
	}
}

func legacyDockerLocalScript(projectDir string) string {
	return filepath.Join(projectDir, ".armin", "docker-scripts", "run-on-docker-local.ps1")
}

func (r *Resolver) ExtraArgs(channel runmode.Mode, action Action, proj discover.Project, app *discover.Application) []string {
	if isDeployAction(action) {
		return nil
	}

	switch channel {
	case runmode.Local:
		switch action {
		case ActionEnable, ActionInstall, ActionUpdate, ActionReinstall:
			return []string{"-Name", proj.Stem, "-SkipStopBeforeStart"}
		case ActionDisable, ActionUninstall:
			return []string{"-StopName", proj.Stem}
		default:
			return nil
		}
	case runmode.LocalDocker, runmode.ServerDocker, runmode.Server:
		switch action {
		case ActionInstall:
			return []string{"-Action", "Install"}
		case ActionUninstall:
			return []string{"-Action", "Uninstall"}
		case ActionUpdate:
			return []string{"-Action", "Update"}
		case ActionReinstall:
			return []string{"-Action", "Reinstall"}
		default:
			return nil
		}
	default:
		return nil
	}
}

func (r *Resolver) RootArg(channel runmode.Mode, action Action) []string {
	if isDeployAction(action) {
		return nil
	}
	if channel == runmode.Local && r.cfg.GitHubRoot != "" {
		return []string{"-Root", r.cfg.GitHubRoot}
	}
	return nil
}
