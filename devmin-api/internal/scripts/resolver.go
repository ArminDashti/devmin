package scripts

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/ArminDashti/devmin-api/internal/config"
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

func (r *Resolver) ScriptPath(channel runmode.Mode, projectDir string) (string, error) {
	switch channel {
	case runmode.HotReload:
		if r.cfg.NativeHotReloadScript != "" {
			if _, err := os.Stat(r.cfg.NativeHotReloadScript); err == nil {
				return r.cfg.NativeHotReloadScript, nil
			}
		}
		return "", fmt.Errorf("hot-reload script not configured")
	case runmode.Local:
		if r.cfg.NativeRunnerScript == "" {
			return "", fmt.Errorf("native runner script not configured")
		}
		return r.cfg.NativeRunnerScript, nil
	case runmode.LocalDocker:
		p := filepath.Join(projectDir, ".armin", "docker-scripts", "run-on-docker-local.ps1")
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

func (r *Resolver) ExtraArgs(channel runmode.Mode, action Action, proj discover.Project, app *discover.Application) []string {
	switch channel {
	case runmode.HotReload:
		switch action {
		case ActionEnable:
			return []string{"-Name", proj.Stem, "-SkipStopBeforeStart"}
		case ActionDisable:
			return []string{"-StopName", proj.Stem}
		default:
			return nil
		}
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

func (r *Resolver) RootArg(channel runmode.Mode) []string {
	if (channel == runmode.HotReload || channel == runmode.Local) && r.cfg.GitHubRoot != "" {
		return []string{"-Root", r.cfg.GitHubRoot}
	}
	return nil
}
