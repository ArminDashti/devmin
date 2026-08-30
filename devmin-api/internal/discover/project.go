package discover

import "path/filepath"

// ProjectType describes how a stack is laid out on disk.
type ProjectType string

const (
	ProjectTypeSplit            ProjectType = "split"
	ProjectTypeCombinedApiWebui ProjectType = "combined-api-webui"
	ProjectTypeWebapp           ProjectType = "webapp"
	ProjectTypeWindows          ProjectType = "windows"
)

// Application is one runnable unit inside a stack.
type Application struct {
	ID           string
	Name         string
	Role         string
	Dir          string
	Stem         string
	InternalPort int
}

// Project is a logical product (stack) with one or more applications.
type Project struct {
	Stem         string
	Type         ProjectType
	RootDir      string
	Applications []Application
	Pair         *Pair
	SkipReason   string
}

func (p Project) PrimaryDir() string {
	if p.RootDir != "" {
		return p.RootDir
	}
	if p.Pair != nil && p.Pair.ApiDir != "" {
		return p.Pair.ApiDir
	}
	for _, a := range p.Applications {
		if a.Dir != "" {
			return a.Dir
		}
	}
	return ""
}

func (p Project) AppByID(appID string) *Application {
	for i := range p.Applications {
		if p.Applications[i].ID == appID {
			return &p.Applications[i]
		}
	}
	return nil
}

func pairToProject(p Pair) Project {
	projType := ProjectTypeSplit
	if p.Combined {
		projType = ProjectTypeCombinedApiWebui
	}
	apiName := p.Stem + "-api"
	if p.ApiDir != "" {
		apiName = baseName(p.ApiDir)
	}
	apps := []Application{{
		ID:           p.Stem + "-api",
		Name:         apiName,
		Role:         "api",
		Dir:          p.ApiDir,
		Stem:         p.Stem,
		InternalPort: p.ApiInternalPort,
	}}
	if p.WebUiDir != "" {
		uiName := p.WebUiName
		if uiName == "" {
			uiName = baseName(p.WebUiDir)
		}
		apps = append(apps, Application{
			ID:           p.Stem + "-webui",
			Name:         uiName,
			Role:         "webui",
			Dir:          p.WebUiDir,
			Stem:         p.Stem,
			InternalPort: p.WebUiInternalPort,
		})
	}
	root := p.ApiDir
	if p.Combined {
		root = p.ApiDir
	}
	return Project{
		Stem:         p.Stem,
		Type:         projType,
		RootDir:      root,
		Applications: apps,
		Pair:         &p,
		SkipReason:   p.SkipReason,
	}
}

func baseName(dir string) string {
	if dir == "" {
		return ""
	}
	return filepath.Base(dir)
}
