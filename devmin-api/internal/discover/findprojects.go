package discover

import (
	"os"
	"path/filepath"
)

// FindProjects discovers stacks from manifests and legacy *-api sibling scan.
func FindProjects(root string) ([]Project, error) {
	claimed := map[string]bool{}
	var projects []Project

	entries, err := os.ReadDir(root)
	if err != nil {
		return nil, err
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		projectDir := filepath.Join(root, e.Name())
		manifestPath := filepath.Join(projectDir, manifestRelPath)
		if _, err := os.Stat(manifestPath); err != nil {
			continue
		}
		m, err := readManifest(projectDir)
		if err != nil {
			continue
		}
		p, err := projectFromManifest(projectDir, m)
		if err != nil {
			continue
		}
		projects = append(projects, p)
		claimed[p.Stem] = true
	}

	pairs, err := FindPairs(root)
	if err != nil {
		return nil, err
	}
	for _, pair := range pairs {
		if claimed[pair.Stem] {
			continue
		}
		if pair.SkipReason == "no WebUI sibling" {
			continue
		}
		projects = append(projects, pairToProject(pair))
	}
	return projects, nil
}

// FindProjectByStem returns one project or nil.
func FindProjectByStem(root, stem string) (*Project, error) {
	projects, err := FindProjects(root)
	if err != nil {
		return nil, err
	}
	for i := range projects {
		if projects[i].Stem == stem {
			return &projects[i], nil
		}
	}
	return nil, nil
}

// FindApplicationByID finds an application across all projects.
func FindApplicationByID(root, appID string) (*Project, *Application, error) {
	projects, err := FindProjects(root)
	if err != nil {
		return nil, nil, err
	}
	for i := range projects {
		if app := projects[i].AppByID(appID); app != nil {
			return &projects[i], app, nil
		}
	}
	return nil, nil, nil
}
