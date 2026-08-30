package endpoints

import (
	"fmt"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/dockerstate"
	"github.com/ArminDashti/devmin-api/internal/hostip"
	"github.com/ArminDashti/devmin-api/internal/nativestate"
	"github.com/ArminDashti/devmin-api/internal/probe"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/serverstate"
)

type Line struct {
	Channel string `json:"channel"`
	URL     string `json:"url"`
	Status  string `json:"status"`
}

type Builder struct {
	cfg         config.Config
	dockerState *dockerstate.StateFile
	nativeState *nativestate.StateFile
	projects    map[string]bool
	hostIP      string
}

func NewBuilder(cfg config.Config, dockerState *dockerstate.StateFile, nativeState *nativestate.StateFile, projects map[string]bool) *Builder {
	host := cfg.HostIP
	if host == "" || host == "127.0.0.1" {
		host = hostip.Resolve(cfg.HostIP)
	}
	return &Builder{
		cfg:         cfg,
		dockerState: dockerState,
		nativeState: nativeState,
		projects:    projects,
		hostIP:      host,
	}
}

func (b *Builder) ForApplication(proj discover.Project, app discover.Application) []Line {
	var lines []Line
	role := app.Role
	pair := proj.Pair

	if pair != nil {
		lines = append(lines, b.nativeLines(proj, role, app.InternalPort)...)
		lines = append(lines, b.localDockerLines(*pair, role)...)
		lines = append(lines, b.serverDockerLines(*pair, role)...)
		lines = append(lines, b.serverLines(*pair, role)...)
	} else if proj.Type == discover.ProjectTypeWindows {
		lines = append(lines, b.nativeLines(proj, role, app.InternalPort)...)
	} else {
		lines = append(lines, b.nativeLines(proj, role, app.InternalPort)...)
		if app.Dir != "" {
			lines = append(lines, Line{
				Channel: string(runmode.LocalDocker),
				URL:     fmt.Sprintf("http://%s:%d/", b.hostIP, app.InternalPort),
				Status:  portStatus(app.InternalPort),
			})
		}
	}

	return dedupeLines(lines)
}

func nativeChannel(proj discover.Project) runmode.Mode {
	if proj.Type == discover.ProjectTypeWindows {
		return runmode.Local
	}
	if proj.Pair != nil && (proj.Type == discover.ProjectTypeSplit || proj.Type == discover.ProjectTypeCombinedApiWebui) {
		return runmode.HotReload
	}
	return runmode.Local
}

func (b *Builder) nativeLines(proj discover.Project, role string, fallbackPort int) []Line {
	return b.nativeLinesForChannel(proj.Stem, role, fallbackPort, nativeChannel(proj))
}

func (b *Builder) nativeLinesForChannel(stem, role string, fallbackPort int, channel runmode.Mode) []Line {
	apiPort, webuiPort, apiURL, webuiURL := nativestate.PortsForStem(b.nativeState, stem)
	var url string
	var port int
	switch role {
	case "api":
		port = apiPort
		url = apiURL
		if url == "" && port > 0 {
			url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		}
		if port == 0 && fallbackPort > 0 {
			port = fallbackPort
			url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		}
	case "webui", "web", "ui":
		port = webuiPort
		url = webuiURL
		if url == "" && port > 0 {
			url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		}
		if port == 0 && fallbackPort > 0 {
			port = fallbackPort
			url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		}
	default:
		port = fallbackPort
		if port > 0 {
			url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		}
	}
	if url == "" {
		return nil
	}
	return []Line{{
		Channel: string(channel),
		URL:     url,
		Status:  portStatus(port),
	}}
}

func (b *Builder) localDockerLines(pair discover.Pair, role string) []Line {
	row := dockerstate.RowByStem(b.dockerState, pair.Stem)
	onDocker := dockerstate.OnDocker(pair.Stem, pair.ApiStack, pair.WebUiStack, b.projects)
	localProject := dockerstate.LocalProjectName(pair.Stem)
	apiPort, webuiPort := dockerstate.HostPortsForProject(localProject)
	if apiPort == 0 && webuiPort == 0 {
		apiPort, webuiPort = dockerstate.HostPortsForProject(pair.ApiStack)
	}
	var url string
	var port int
	switch role {
	case "api":
		if row != nil && row.ApiURL != "" {
			url = row.ApiURL
		} else if apiPort > 0 {
			port = apiPort
			url = fmt.Sprintf("http://%s:%d/", b.hostIP, apiPort)
		}
	case "webui", "web", "ui":
		if row != nil && row.WebUiURL != "" {
			url = row.WebUiURL
		} else if webuiPort > 0 {
			port = webuiPort
			url = fmt.Sprintf("http://%s:%d/", b.hostIP, webuiPort)
		}
	default:
		if pair.ApiInternalPort > 0 {
			port = pair.ApiInternalPort
			url = fmt.Sprintf("http://%s:%d/", b.hostIP, port)
		}
	}
	if url == "" {
		return nil
	}
	status := "Down"
	if onDocker || portStatus(port) == "UP" {
		if onDocker || probe.PortListening(b.hostIP, port) {
			status = "UP"
		}
	}
	return []Line{{Channel: string(runmode.LocalDocker), URL: url, Status: status}}
}

func (b *Builder) serverDockerLines(pair discover.Pair, role string) []Line {
	cfg, err := serverstate.ReadDeployConfig(pair.ApiDir)
	if err != nil {
		return nil
	}
	url := serverstate.PublicURL(cfg.StackName)
	if url == "" {
		return nil
	}
	if role == "webui" || role == "web" || role == "ui" {
		url = serverstate.PublicURL(cfg.StackName)
	}
	onServer := serverstate.OnServer(cfg, b.cfg.ServerSSHTimeoutSec)
	status := "Down"
	if onServer {
		status = "UP"
	}
	return []Line{{Channel: string(runmode.ServerDocker), URL: url, Status: status}}
}

func (b *Builder) serverLines(pair discover.Pair, role string) []Line {
	scriptDir := pair.ApiDir
	if role == "webui" && pair.WebUiDir != "" {
		scriptDir = pair.WebUiDir
	}
	if !serverstate.HasBareServerDeploy(scriptDir) {
		return nil
	}
	cfg, err := serverstate.ReadBareDeployConfig(scriptDir)
	if err != nil {
		return nil
	}
	url := cfg.PublicURL
	if url == "" {
		url = serverstate.PublicURL(cfg.StackName)
	}
	return []Line{{Channel: string(runmode.Server), URL: url, Status: "Down"}}
}

func portStatus(port int) string {
	if port > 0 && probe.PortListening("127.0.0.1", port) {
		return "UP"
	}
	return "Down"
}

func dedupeLines(lines []Line) []Line {
	seen := map[string]bool{}
	out := make([]Line, 0, len(lines))
	for _, l := range lines {
		if l.URL == "" {
			continue
		}
		key := l.Channel + "|" + l.URL
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, l)
	}
	return out
}
