package runmode

import "fmt"

type Mode string

const (
	HotReload    Mode = "hotReload"
	Local        Mode = "local"
	LocalDocker  Mode = "localDocker"
	ServerDocker Mode = "serverDocker"
	Server       Mode = "server"
)

func Parse(raw string) (Mode, error) {
	switch raw {
	case string(HotReload):
		return HotReload, nil
	case string(Local):
		return Local, nil
	case string(LocalDocker):
		return LocalDocker, nil
	case string(ServerDocker):
		return ServerDocker, nil
	case string(Server):
		return Server, nil
	default:
		return "", fmt.Errorf("invalid channel %q (want hotReload, local, localDocker, serverDocker, or server)", raw)
	}
}

func Default() Mode {
	return LocalDocker
}

func (m Mode) Label() string {
	switch m {
	case HotReload:
		return "Hot-reload"
	case Local:
		return "Local"
	case LocalDocker:
		return "Local Docker"
	case ServerDocker:
		return "Server Docker"
	case Server:
		return "Server"
	default:
		return string(m)
	}
}
