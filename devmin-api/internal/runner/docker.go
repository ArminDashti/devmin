package runner

import (
	"context"

	"github.com/ArminDashti/devmin-api/internal/discover"
)

// DockerRunner starts/stops local Docker stacks via the run-all-apps-on-local-docker script.
type DockerRunner struct {
	scriptPath string
	root       string
}

func NewDockerRunner(scriptPath, root string) *DockerRunner {
	return &DockerRunner{scriptPath: scriptPath, root: root}
}

func (d *DockerRunner) Start(_ context.Context, pair discover.Pair) error {
	return runPowerShell(d.scriptPath, []string{
		"-Root", d.root,
		"-Name", pair.Stem,
		"-SkipStopBeforeStart",
	})
}

func (d *DockerRunner) Stop(_ context.Context, pair discover.Pair) error {
	return runPowerShell(d.scriptPath, []string{
		"-Root", d.root,
		"-StopName", pair.Stem,
	})
}
