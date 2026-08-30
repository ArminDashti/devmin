package runner

import (
	"context"
	"fmt"

	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/serverstate"
)

// BareServerRunner deploys non-Docker server targets via run-on-server.ps1.
type BareServerRunner struct{}

func NewBareServerRunner() *BareServerRunner {
	return &BareServerRunner{}
}

func (b *BareServerRunner) Start(_ context.Context, pair discover.Pair) error {
	dirs, err := bareServerDirs(pair)
	if err != nil {
		return err
	}
	for _, dir := range dirs {
		script := serverstate.BareServerScriptPath(dir)
		if err := runPowerShell(script, []string{"-Action", "Install"}); err != nil {
			return err
		}
	}
	return nil
}

func (b *BareServerRunner) Stop(_ context.Context, pair discover.Pair) error {
	dirs, err := bareServerDirs(pair)
	if err != nil {
		return err
	}
	for _, dir := range dirs {
		script := serverstate.BareServerScriptPath(dir)
		if err := runPowerShell(script, []string{"-Action", "Uninstall"}); err != nil {
			return err
		}
	}
	return nil
}

func bareServerDirs(pair discover.Pair) ([]string, error) {
	if !serverstate.HasBareServerDeploy(pair.ApiDir) {
		return nil, fmt.Errorf("bare server scripts missing for %s", pair.Stem)
	}
	dirs := []string{pair.ApiDir}
	if !pair.Combined && pair.WebUiDir != "" && serverstate.HasBareServerDeploy(pair.WebUiDir) {
		dirs = append(dirs, pair.WebUiDir)
	}
	return dirs, nil
}
