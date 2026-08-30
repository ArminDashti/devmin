package discover

import (
	"os"
	"path/filepath"
	"testing"
)

func TestFindProjectsDevminManifest(t *testing.T) {
	root := filepath.Join("..", "..", "..")
	if _, err := os.Stat(filepath.Join(root, ".armin", "devmin.yaml")); err != nil {
		t.Skip("devmin manifest not present")
	}
	projects, err := FindProjects(root)
	if err != nil {
		t.Fatal(err)
	}
	var devmin *Project
	for i := range projects {
		if projects[i].Stem == "devmin" {
			devmin = &projects[i]
			break
		}
	}
	if devmin == nil {
		t.Fatal("expected devmin stack from manifest")
	}
	if len(devmin.Applications) < 2 {
		t.Fatalf("expected api+webui apps, got %d", len(devmin.Applications))
	}
}
