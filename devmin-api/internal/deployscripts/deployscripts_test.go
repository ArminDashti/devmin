package deployscripts

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/runmode"
)

func TestRepoNameFromMonorepoAPI(t *testing.T) {
	proj := discover.Project{
		Stem:    "devmin",
		RootDir: filepath.Join("C:/Users/armin/GitHub/devmin", "devmin-api"),
	}
	got := RepoName("C:/Users/armin/GitHub", proj)
	if got != "devmin" {
		t.Fatalf("repo name = %q, want devmin", got)
	}
}

func TestScriptPathInstallLocalDocker(t *testing.T) {
	root := filepath.Clean("../../../")
	repo := "devmin"
	path, err := ScriptPath(root, repo, runmode.LocalDocker, "install")
	if err != nil {
		t.Fatalf("ScriptPath: %v", err)
	}
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("script missing: %v", err)
	}
}

func TestReadConfigInstallDockerLocal(t *testing.T) {
	root := filepath.Clean("../../../")
	cfg, err := ReadConfig(root, "devmin", runmode.LocalDocker, "install")
	if err != nil {
		t.Fatalf("ReadConfig: %v", err)
	}
	if cfg["stack_name"] != "devmin" {
		t.Fatalf("stack_name = %q", cfg["stack_name"])
	}
}
