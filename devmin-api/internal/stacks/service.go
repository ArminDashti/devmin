package stacks

import (
	"context"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/dockerparams"
	"github.com/ArminDashti/devmin-api/internal/dockerstate"
	"github.com/ArminDashti/devmin-api/internal/endpoints"
	"github.com/ArminDashti/devmin-api/internal/nativestate"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/serverstate"
	"github.com/ArminDashti/devmin-api/internal/store"
)

type ChannelState struct {
	Enabled   bool `json:"enabled"`
	Available bool `json:"available"`
	Reason    string `json:"reason,omitempty"`
}

type ApplicationDTO struct {
	ID           string                 `json:"id"`
	Name         string                 `json:"name"`
	Role         string                 `json:"role"`
	Stem         string                 `json:"stem"`
	InternalPort int                    `json:"internalPort"`
	Endpoints    []endpoints.Line       `json:"endpoints"`
	Channels     map[string]ChannelState `json:"channels"`
}

type StackDTO struct {
	Stem         string           `json:"stem"`
	Type         string           `json:"type"`
	RootDir      string           `json:"rootDir"`
	SkipReason   string           `json:"skipReason,omitempty"`
	Applications []ApplicationDTO `json:"applications"`
}

type Service struct {
	cfg   config.Config
	store *store.Store
}

func NewService(cfg config.Config, st *store.Store) *Service {
	return &Service{cfg: cfg, store: st}
}

func (s *Service) loadContext(ctx context.Context) ([]discover.Project, *dockerstate.StateFile, *nativestate.StateFile, map[string]bool, map[string]store.AppPreference, error) {
	projects, err := discover.FindProjects(s.cfg.GitHubRoot)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	dockerState, err := dockerstate.ReadState(s.cfg.DockerStatePath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	nativeState, err := nativestate.ReadState(s.cfg.NativeStatePath)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	projectsMap, err := dockerstate.RunningProjects()
	if err != nil {
		projectsMap = map[string]bool{}
	}
	prefs, err := s.store.ListAppPreferences(ctx)
	if err != nil {
		return nil, nil, nil, nil, nil, err
	}
	return projects, dockerState, nativeState, projectsMap, prefs, nil
}

func (s *Service) List(ctx context.Context) ([]StackDTO, error) {
	projects, dockerState, nativeState, projectsMap, prefs, err := s.loadContext(ctx)
	if err != nil {
		return nil, err
	}
	ep := endpoints.NewBuilder(s.cfg, dockerState, nativeState, projectsMap)
	out := make([]StackDTO, 0, len(projects))
	for _, proj := range projects {
		out = append(out, s.buildStack(proj, ep, prefs))
	}
	return out, nil
}

func (s *Service) Get(ctx context.Context, stem string) (*StackDTO, error) {
	projects, dockerState, nativeState, projectsMap, prefs, err := s.loadContext(ctx)
	if err != nil {
		return nil, err
	}
	ep := endpoints.NewBuilder(s.cfg, dockerState, nativeState, projectsMap)
	for _, proj := range projects {
		if proj.Stem == stem {
			dto := s.buildStack(proj, ep, prefs)
			return &dto, nil
		}
	}
	return nil, nil
}

func (s *Service) GetApplication(ctx context.Context, appID string) (*ApplicationDTO, *StackDTO, error) {
	projects, dockerState, nativeState, projectsMap, prefs, err := s.loadContext(ctx)
	if err != nil {
		return nil, nil, err
	}
	ep := endpoints.NewBuilder(s.cfg, dockerState, nativeState, projectsMap)
	for _, proj := range projects {
		app := proj.AppByID(appID)
		if app == nil {
			continue
		}
		stack := s.buildStack(proj, ep, prefs)
		for _, a := range stack.Applications {
			if a.ID == appID {
				return &a, &stack, nil
			}
		}
	}
	return nil, nil, nil
}

func (s *Service) buildStack(proj discover.Project, ep *endpoints.Builder, prefs map[string]store.AppPreference) StackDTO {
	pref := prefs[proj.Stem]
	apps := make([]ApplicationDTO, 0, len(proj.Applications))
	for _, app := range proj.Applications {
		apps = append(apps, s.buildApp(proj, app, ep, pref))
	}
	return StackDTO{
		Stem:         proj.Stem,
		Type:         string(proj.Type),
		RootDir:      proj.RootDir,
		SkipReason:   proj.SkipReason,
		Applications: apps,
	}
}

func (s *Service) buildApp(proj discover.Project, app discover.Application, ep *endpoints.Builder, pref store.AppPreference) ApplicationDTO {
	return ApplicationDTO{
		ID:           app.ID,
		Name:         app.Name,
		Role:         app.Role,
		Stem:         app.Stem,
		InternalPort: app.InternalPort,
		Endpoints:    ep.ForApplication(proj, app),
		Channels:     channelStates(proj, app, pref),
	}
}

func channelStates(proj discover.Project, app discover.Application, pref store.AppPreference) map[string]ChannelState {
	hrAvail := supportsHotReload(proj)
	localAvail := supportsLocalNative(proj)
	out := map[string]ChannelState{
		string(runmode.HotReload):    {Enabled: pref.HotReloadEnabled, Available: hrAvail},
		string(runmode.Local):        {Enabled: pref.LocalEnabled, Available: localAvail},
		string(runmode.LocalDocker):  {Enabled: pref.LocalDockerEnabled, Available: true},
		string(runmode.ServerDocker): {Enabled: pref.ServerDockerEnabled, Available: false},
		string(runmode.Server):       {Enabled: pref.ServerEnabled, Available: false},
	}
	if proj.Type == discover.ProjectTypeWindows {
		out[string(runmode.LocalDocker)] = ChannelState{Available: false, Reason: "Windows app"}
		out[string(runmode.ServerDocker)] = ChannelState{Available: false, Reason: "Windows app"}
		out[string(runmode.Server)] = ChannelState{Available: false, Reason: "Windows app"}
		return out
	}
	pair := proj.Pair
	if pair == nil {
		return out
	}
	if pair.SkipReason != "" && pair.LocalCompose == "" {
		out[string(runmode.LocalDocker)] = ChannelState{
			Enabled:   pref.LocalDockerEnabled,
			Available: false,
			Reason:    pair.SkipReason,
		}
	}
	if !pair.HasServerDeploy {
		out[string(runmode.ServerDocker)] = ChannelState{
			Enabled:   pref.ServerDockerEnabled,
			Available: false,
			Reason:    "Server Docker scripts missing",
		}
	} else {
		out[string(runmode.ServerDocker)] = ChannelState{
			Enabled:   pref.ServerDockerEnabled,
			Available: true,
		}
	}
	bareDir := app.Dir
	if bareDir == "" {
		bareDir = pair.ApiDir
	}
	if serverstate.HasBareServerDeploy(bareDir) {
		out[string(runmode.Server)] = ChannelState{
			Enabled:   pref.ServerEnabled,
			Available: true,
		}
	} else {
		out[string(runmode.Server)] = ChannelState{
			Enabled:   pref.ServerEnabled,
			Available: false,
			Reason:    "Server scripts missing",
		}
	}
	_, err := dockerparams.Read(bareDir, dockerparams.TargetLocal)
	if err != nil && pair.LocalCompose == "" {
		if out[string(runmode.LocalDocker)].Available {
			out[string(runmode.LocalDocker)] = ChannelState{
				Available: false,
				Reason:    "No local docker config",
			}
		}
	}
	return out
}

func supportsHotReload(proj discover.Project) bool {
	if proj.Type == discover.ProjectTypeWindows {
		return false
	}
	return proj.Pair != nil && (proj.Type == discover.ProjectTypeSplit || proj.Type == discover.ProjectTypeCombinedApiWebui)
}

func supportsLocalNative(proj discover.Project) bool {
	if proj.Type == discover.ProjectTypeWindows {
		return true
	}
	if proj.Pair != nil && (proj.Type == discover.ProjectTypeSplit || proj.Type == discover.ProjectTypeCombinedApiWebui) {
		return false
	}
	return true
}
