package settings

import (
	"context"
	"encoding/json"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/store"
)

const settingsKey = "platform"

type LocalDockerSettings struct {
	Network        string `json:"network"`
	PublishHost    string `json:"publishHost"`
	GitHubRoot     string `json:"githubRoot"`
	DeleteVolume   string `json:"deleteVolume"`
	DeleteImage    string `json:"deleteImage"`
}

type ServerDockerSettings struct {
	SSHTarget   string `json:"sshTarget"`
	VolumeBase  string `json:"volumeBase"`
	TimeoutSec  int    `json:"timeoutSec"`
}

type ServerSettings struct {
	SSHTarget   string `json:"sshTarget"`
	DeployRoot  string `json:"deployRoot"`
	SSHEnvKey   string `json:"sshEnvKey"`
}

type PlatformSettings struct {
	LocalDocker  LocalDockerSettings  `json:"localDocker"`
	ServerDocker ServerDockerSettings `json:"serverDocker"`
	Server       ServerSettings       `json:"server"`
}

type Service struct {
	cfg   config.Config
	store *store.Store
}

func NewService(cfg config.Config, st *store.Store) *Service {
	return &Service{cfg: cfg, store: st}
}

func (s *Service) defaults() PlatformSettings {
	return PlatformSettings{
		LocalDocker: LocalDockerSettings{
			Network:      "t3-net",
			PublishHost:  s.cfg.HostIP,
			GitHubRoot:   s.cfg.GitHubRoot,
			DeleteVolume: "no",
			DeleteImage:  "yes",
		},
		ServerDocker: ServerDockerSettings{
			SSHTarget:  "ssh t3",
			VolumeBase: "/cloud-admin/docker-volumes",
			TimeoutSec: s.cfg.ServerSSHTimeoutSec,
		},
		Server: ServerSettings{
			SSHTarget:  "ssh t3",
			DeployRoot: "/cloud-admin/apps",
			SSHEnvKey:  "DEVMIN_SERVER_SSH",
		},
	}
}

func (s *Service) Get(ctx context.Context) (PlatformSettings, error) {
	raw, ok, err := s.store.GetGlobalSetting(ctx, settingsKey)
	if err != nil {
		return PlatformSettings{}, err
	}
	def := s.defaults()
	if !ok {
		return def, nil
	}
	var saved PlatformSettings
	if err := json.Unmarshal(raw, &saved); err != nil {
		return def, nil
	}
	mergeSettings(&def, saved)
	return def, nil
}

func (s *Service) Put(ctx context.Context, in PlatformSettings) error {
	raw, err := json.Marshal(in)
	if err != nil {
		return err
	}
	return s.store.SetGlobalSetting(ctx, settingsKey, raw)
}

func mergeSettings(base *PlatformSettings, saved PlatformSettings) {
	if saved.LocalDocker.Network != "" {
		base.LocalDocker.Network = saved.LocalDocker.Network
	}
	if saved.LocalDocker.PublishHost != "" {
		base.LocalDocker.PublishHost = saved.LocalDocker.PublishHost
	}
	if saved.LocalDocker.GitHubRoot != "" {
		base.LocalDocker.GitHubRoot = saved.LocalDocker.GitHubRoot
	}
	if saved.LocalDocker.DeleteVolume != "" {
		base.LocalDocker.DeleteVolume = saved.LocalDocker.DeleteVolume
	}
	if saved.LocalDocker.DeleteImage != "" {
		base.LocalDocker.DeleteImage = saved.LocalDocker.DeleteImage
	}
	if saved.ServerDocker.SSHTarget != "" {
		base.ServerDocker.SSHTarget = saved.ServerDocker.SSHTarget
	}
	if saved.ServerDocker.VolumeBase != "" {
		base.ServerDocker.VolumeBase = saved.ServerDocker.VolumeBase
	}
	if saved.ServerDocker.TimeoutSec > 0 {
		base.ServerDocker.TimeoutSec = saved.ServerDocker.TimeoutSec
	}
	if saved.Server.SSHTarget != "" {
		base.Server.SSHTarget = saved.Server.SSHTarget
	}
	if saved.Server.DeployRoot != "" {
		base.Server.DeployRoot = saved.Server.DeployRoot
	}
	if saved.Server.SSHEnvKey != "" {
		base.Server.SSHEnvKey = saved.Server.SSHEnvKey
	}
}
