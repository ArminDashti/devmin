package actions

import (
	"context"
	"fmt"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/runner"
	"github.com/ArminDashti/devmin-api/internal/scripts"
	"github.com/ArminDashti/devmin-api/internal/store"
)

type Service struct {
	cfg      config.Config
	store    *store.Store
	router   *runner.Router
	resolver *scripts.Resolver
	invoker  *scripts.Invoker
}

func NewService(cfg config.Config, st *store.Store, router *runner.Router, resolver *scripts.Resolver, invoker *scripts.Invoker) *Service {
	return &Service{cfg: cfg, store: st, router: router, resolver: resolver, invoker: invoker}
}

type Request struct {
	Stem    string
	AppID   string
	Channel runmode.Mode
	Action  scripts.Action
}

func (s *Service) Run(ctx context.Context, req Request) (*scripts.Job, error) {
	proj, app, err := s.findTarget(req.Stem, req.AppID)
	if err != nil {
		return nil, err
	}
	if s.router.IsRunning(proj.Stem) {
		return nil, fmt.Errorf("action already in progress for %s", proj.Stem)
	}

	projectDir := s.resolver.ProjectDir(*proj, app)
	scriptPath, err := s.resolver.ScriptPath(req.Channel, projectDir)
	if err != nil {
		return nil, err
	}

	appID := ""
	if app != nil {
		appID = app.ID
	}

	switch req.Action {
	case scripts.ActionEnable:
		if err := s.setEnabled(ctx, proj.Stem, req.Channel, true); err != nil {
			return nil, err
		}
		args := s.resolver.ExtraArgs(req.Channel, req.Action, *proj, app)
		args = append(s.resolver.RootArg(req.Channel), args...)
		return s.invoker.RunScript(ctx, proj.Stem, appID, string(req.Channel), req.Action, scriptPath, args)
	case scripts.ActionDisable:
		if err := s.setEnabled(ctx, proj.Stem, req.Channel, false); err != nil {
			return nil, err
		}
		args := s.resolver.ExtraArgs(req.Channel, req.Action, *proj, app)
		args = append(s.resolver.RootArg(req.Channel), args...)
		return s.invoker.RunScript(ctx, proj.Stem, appID, string(req.Channel), req.Action, scriptPath, args)
	case scripts.ActionInstall, scripts.ActionUpdate, scripts.ActionReinstall, scripts.ActionUninstall:
		if req.Action == scripts.ActionInstall || req.Action == scripts.ActionReinstall {
			if err := s.setEnabled(ctx, proj.Stem, req.Channel, true); err != nil {
				return nil, err
			}
		}
		if req.Action == scripts.ActionUninstall {
			if err := s.setEnabled(ctx, proj.Stem, req.Channel, false); err != nil {
				return nil, err
			}
		}
		args := s.resolver.ExtraArgs(req.Channel, req.Action, *proj, app)
		return s.invoker.RunScript(ctx, proj.Stem, appID, string(req.Channel), req.Action, scriptPath, args)
	default:
		return nil, fmt.Errorf("unsupported action %s", req.Action)
	}
}

func (s *Service) GetJob(id string) (*scripts.Job, bool) {
	return s.invoker.Job(id)
}

func (s *Service) findTarget(stem, appID string) (*discover.Project, *discover.Application, error) {
	if appID != "" {
		proj, app, err := discover.FindApplicationByID(s.cfg.GitHubRoot, appID)
		if err != nil {
			return nil, nil, err
		}
		if proj == nil {
			return nil, nil, fmt.Errorf("application not found: %s", appID)
		}
		return proj, app, nil
	}
	if stem == "" {
		return nil, nil, fmt.Errorf("stem or appId required")
	}
	proj, err := discover.FindProjectByStem(s.cfg.GitHubRoot, stem)
	if err != nil {
		return nil, nil, err
	}
	if proj == nil {
		return nil, nil, fmt.Errorf("stack not found: %s", stem)
	}
	return proj, nil, nil
}

func (s *Service) setEnabled(ctx context.Context, stem string, channel runmode.Mode, enabled bool) error {
	return s.store.SetModeEnabled(ctx, stem, channel, enabled)
}
