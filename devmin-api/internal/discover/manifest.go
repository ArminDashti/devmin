package discover

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

const manifestRelPath = ".armin/devmin.yaml"

type manifestFile struct {
	Stack        string              `yaml:"stack"`
	Type         string              `yaml:"type"`
	Root         string              `yaml:"root"`
	Applications []manifestApp       `yaml:"applications"`
	Endpoints    []manifestEndpoint  `yaml:"endpoints"`
}

type manifestApp struct {
	ID   string `yaml:"id"`
	Role string `yaml:"role"`
	Dir  string `yaml:"dir"`
}

type manifestEndpoint struct {
	Application string `yaml:"application"`
	Channel     string `yaml:"channel"`
	URL         string `yaml:"url"`
}

func readManifest(projectDir string) (*manifestFile, error) {
	path := filepath.Join(projectDir, manifestRelPath)
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var m manifestFile
	if err := yaml.Unmarshal(data, &m); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	if m.Stack == "" {
		return nil, fmt.Errorf("manifest missing stack in %s", path)
	}
	return &m, nil
}

func projectFromManifest(projectDir string, m *manifestFile) (Project, error) {
	rootRel := strings.TrimSpace(m.Root)
	if rootRel == "" {
		rootRel = "."
	}
	rootDir := filepath.Join(projectDir, filepath.FromSlash(rootRel))
	rootDir = filepath.Clean(rootDir)

	projType, err := parseProjectType(m.Type)
	if err != nil {
		return Project{}, err
	}

	apps := make([]Application, 0, len(m.Applications))
	for _, ma := range m.Applications {
		id := strings.TrimSpace(ma.ID)
		if id == "" {
			continue
		}
		dirRel := strings.TrimSpace(ma.Dir)
		if dirRel == "" {
			dirRel = "."
		}
		appDir := filepath.Join(projectDir, filepath.FromSlash(dirRel))
		appDir = filepath.Clean(appDir)
		port := resolveInternalPort(appDir, 0)
		apps = append(apps, Application{
			ID:           id,
			Name:         id,
			Role:         strings.TrimSpace(ma.Role),
			Dir:          appDir,
			Stem:         m.Stack,
			InternalPort: port,
		})
	}
	if len(apps) == 0 {
		return Project{}, fmt.Errorf("manifest %s has no applications", m.Stack)
	}

	p := Project{
		Stem:         m.Stack,
		Type:         projType,
		RootDir:      rootDir,
		Applications: apps,
	}
	p.Pair = manifestToPair(p, m)
	return p, nil
}

func parseProjectType(raw string) (ProjectType, error) {
	t := ProjectType(strings.TrimSpace(raw))
	switch t {
	case ProjectTypeSplit, ProjectTypeCombinedApiWebui, ProjectTypeWebapp, ProjectTypeWindows, "":
		if t == "" {
			return ProjectTypeSplit, nil
		}
		return t, nil
	default:
		return "", fmt.Errorf("unknown project type %q", raw)
	}
}

func manifestToPair(p Project, m *manifestFile) *Pair {
	if p.Type == ProjectTypeWindows {
		return nil
	}
	pair := Pair{Stem: p.Stem}
	for _, a := range p.Applications {
		switch strings.ToLower(a.Role) {
		case "api":
			pair.ApiDir = a.Dir
			pair.ApiInternalPort = a.InternalPort
		case "webui", "web", "ui":
			pair.WebUiDir = a.Dir
			pair.WebUiName = a.Name
			pair.WebUiInternalPort = a.InternalPort
		default:
			if pair.ApiDir == "" {
				pair.ApiDir = a.Dir
				pair.ApiInternalPort = a.InternalPort
			}
		}
	}
	if p.Type == ProjectTypeCombinedApiWebui {
		pair.Combined = true
	}
	if pair.ApiDir != "" {
		resolveProductionPlan(&pair)
		pair.ApiStack = stackName(pair.ApiDir, p.Stem+"-api")
		if pair.WebUiDir != "" {
			pair.WebUiStack = stackName(pair.WebUiDir, p.Stem+"-webui")
		}
		if pair.Combined {
			pair.WebUiStack = pair.ApiStack
		}
		pair.HasServerDeploy = hasServerDeploy(pair)
	}
	return &pair
}
