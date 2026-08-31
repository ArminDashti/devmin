package endpoints

import (
	"net"
	"os"
	"path/filepath"
	"testing"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/nativestate"
	"github.com/ArminDashti/devmin-api/internal/runmode"
)

func TestHotReloadSkipsDockerInternalPortFallback(t *testing.T) {
	state := &nativestate.StateFile{Processes: []nativestate.ProcRow{}}
	b := NewBuilder(config.Config{}, nil, state, map[string]bool{})
	proj := discover.Project{
		Stem: "exa",
		Type: discover.ProjectTypeSplit,
		Pair: &discover.Pair{Stem: "exa"},
	}
	app := discover.Application{Role: "webui", InternalPort: 80, Dir: t.TempDir()}

	lines := b.nativeLinesForChannel(proj.Stem, app.Role, app.Dir, app.InternalPort, runmode.HotReload)
	if len(lines) != 0 {
		t.Fatalf("expected no hot-reload endpoint without native state or listening publish port, got %+v", lines)
	}
}

func TestHotReloadUsesPublishPortWhenListening(t *testing.T) {
	dir := t.TempDir()
	dockerDir := filepath.Join(dir, ".armin", "docker-scripts")
	if err := os.MkdirAll(dockerDir, 0o755); err != nil {
		t.Fatal(err)
	}
	yaml := `publish_port: "5195"
internal_port: "80"
`
	if err := os.WriteFile(filepath.Join(dockerDir, "run-on-docker-local.yaml"), []byte(yaml), 0o644); err != nil {
		t.Fatal(err)
	}

	ln, err := net.Listen("tcp", "127.0.0.1:5195")
	if err != nil {
		t.Skip("port 5195 busy:", err)
	}
	defer ln.Close()

	state := &nativestate.StateFile{Processes: []nativestate.ProcRow{}}
	b := NewBuilder(config.Config{}, nil, state, map[string]bool{})
	lines := b.nativeLinesForChannel("devmin", "webui", dir, 80, runmode.HotReload)
	if len(lines) != 1 {
		t.Fatalf("expected one hot-reload endpoint, got %+v", lines)
	}
	if lines[0].Status != "UP" {
		t.Fatalf("expected UP, got %q", lines[0].Status)
	}
	if lines[0].URL != "http://127.0.0.1:5195/" {
		t.Fatalf("unexpected url %q", lines[0].URL)
	}
}

func TestLocalUsesFallbackPort(t *testing.T) {
	state := &nativestate.StateFile{Processes: []nativestate.ProcRow{}}
	b := NewBuilder(config.Config{}, nil, state, map[string]bool{})

	lines := b.nativeLinesForChannel("desktop-app", "ui", "", 8080, runmode.Local)
	if len(lines) != 1 {
		t.Fatalf("expected one local endpoint, got %+v", lines)
	}
	if lines[0].URL != "http://127.0.0.1:8080/" {
		t.Fatalf("unexpected url %q", lines[0].URL)
	}
}
