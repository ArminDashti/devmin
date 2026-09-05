package resolve

import (
	"fmt"
	"strings"

	"github.com/ArminDashti/devmin-cli/internal/api"
)

// Target is a resolved stack stem and optional application id.
type Target struct {
	Stem  string
	AppID string
	Name  string
	App   *api.Application
	Stack *api.Stack
}

// AppName resolves stem first, then application id.
func AppName(stacks []api.Stack, name string) (*Target, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("app name required")
	}

	for i := range stacks {
		st := &stacks[i]
		if strings.EqualFold(st.Stem, name) {
			return &Target{Stem: st.Stem, Name: st.Stem, Stack: st}, nil
		}
	}

	for i := range stacks {
		st := &stacks[i]
		for j := range st.Applications {
			app := &st.Applications[j]
			if strings.EqualFold(app.ID, name) || strings.EqualFold(app.Name, name) {
				return &Target{
					Stem:  st.Stem,
					AppID: app.ID,
					Name:  app.Name,
					App:   app,
					Stack: st,
				}, nil
			}
		}
	}

	return nil, fmt.Errorf("app not found: %s", name)
}

const (
	ChannelLocal        = "local"
	ChannelLocalDocker  = "localDocker"
	ChannelServerDocker = "serverDocker"
)

// CLIChannel maps CLI channel names to API channel ids.
func CLIChannel(raw string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "local":
		return ChannelLocal, nil
	case "local-docker", "localdocker", "local-dcoker":
		return ChannelLocalDocker, nil
	case "server-docker", "serverdocker":
		return ChannelServerDocker, nil
	default:
		return "", fmt.Errorf("unknown channel %q (want local|local-docker|server-docker)", raw)
	}
}

// CLIAction maps CLI verbs to API action names.
func CLIAction(verb string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(verb)) {
	case "install":
		return "install", nil
	case "remove", "uninstall":
		return "uninstall", nil
	case "update":
		return "update", nil
	case "reinstall":
		return "reinstall", nil
	default:
		return "", fmt.Errorf("unknown action %q", verb)
	}
}

func EndpointStatus(app api.Application, channel string) (url string, up bool, available bool, reason string) {
	if ch, ok := app.Channels[channel]; ok {
		available = ch.Available
		reason = ch.Reason
	}
	for _, ep := range app.Endpoints {
		if ep.Channel == channel {
			url = ep.URL
			up = strings.EqualFold(ep.Status, "UP")
			return
		}
	}
	return
}

func AppIsOnline(app api.Application) bool {
	for _, ch := range []string{ChannelLocal, ChannelLocalDocker, ChannelServerDocker} {
		_, up, available, _ := EndpointStatus(app, ch)
		if available && up {
			return true
		}
	}
	return false
}

func FlattenApps(stacks []api.Stack) []api.Application {
	out := make([]api.Application, 0)
	for _, st := range stacks {
		out = append(out, st.Applications...)
	}
	return out
}
