package endpoints

import (
	"testing"

	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/nativestate"
	"github.com/ArminDashti/devmin-api/internal/runmode"
)

func TestLocalSkipsSplitProjectNativeEndpoints(t *testing.T) {
	state := &nativestate.StateFile{Processes: []nativestate.ProcRow{}}
	b := NewBuilder(config.Config{}, nil, state, map[string]bool{})
	proj := discover.Project{
		Stem: "exa",
		Type: discover.ProjectTypeSplit,
		Pair: &discover.Pair{Stem: "exa"},
	}
	app := discover.Application{Role: "webui", InternalPort: 80}

	lines := b.nativeLines(proj, app)
	if len(lines) != 0 {
		t.Fatalf("expected no local endpoint for split project, got %+v", lines)
	}
}

func TestLocalUsesFallbackPort(t *testing.T) {
	state := &nativestate.StateFile{Processes: []nativestate.ProcRow{}}
	b := NewBuilder(config.Config{}, nil, state, map[string]bool{})

	lines := b.nativeLinesForChannel("desktop-app", "ui", 8080, runmode.Local)
	if len(lines) != 1 {
		t.Fatalf("expected one local endpoint, got %+v", lines)
	}
	if lines[0].URL != "http://127.0.0.1:8080/" {
		t.Fatalf("unexpected url %q", lines[0].URL)
	}
}
