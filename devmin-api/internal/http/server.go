package httpserver

import (
	"errors"
	"net/http"
	"strings"

	"github.com/ArminDashti/devmin-api/internal/actions"
	"github.com/ArminDashti/devmin-api/internal/apps"
	"github.com/ArminDashti/devmin-api/internal/auth"
	"github.com/ArminDashti/devmin-api/internal/config"
	"github.com/ArminDashti/devmin-api/internal/dockerparams"
	"github.com/ArminDashti/devmin-api/internal/discover"
	"github.com/ArminDashti/devmin-api/internal/runmode"
	"github.com/ArminDashti/devmin-api/internal/scripts"
	"github.com/ArminDashti/devmin-api/internal/settings"
	"github.com/ArminDashti/devmin-api/internal/stacks"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

type Server struct {
	cfg         config.Config
	auth        *auth.Service
	appsSvc     *apps.Service
	stacksSvc   *stacks.Service
	actionsSvc  *actions.Service
	settingsSvc *settings.Service
}

func New(
	cfg config.Config,
	authSvc *auth.Service,
	appsSvc *apps.Service,
	stacksSvc *stacks.Service,
	actionsSvc *actions.Service,
	settingsSvc *settings.Service,
) *Server {
	return &Server{
		cfg:         cfg,
		auth:        authSvc,
		appsSvc:     appsSvc,
		stacksSvc:   stacksSvc,
		actionsSvc:  actionsSvc,
		settingsSvc: settingsSvc,
	}
}

func (s *Server) Router() *gin.Engine {
	r := gin.New()
	r.Use(gin.Recovery(), gin.Logger())
	r.Use(cors.New(cors.Config{
		AllowOrigins:     s.cfg.CORSOrigins,
		AllowMethods:     []string{"GET", "POST", "PUT", "PATCH", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Accept", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")
	{
		v1.GET("/health", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"status": "ok"})
		})
		v1.POST("/auth/login", s.postLogin)
	}

	protected := v1.Group("")
	protected.Use(jwtMiddleware(s.auth))
	{
		protected.GET("/apps", s.getApps)
		protected.PATCH("/apps/:stem", s.patchApp)
		protected.GET("/stacks", s.getStacks)
		protected.GET("/stacks/:stem", s.getStack)
		protected.GET("/applications/:appId", s.getApplication)
		protected.POST("/actions", s.postAction)
		protected.GET("/actions/:id", s.getAction)
		protected.GET("/settings", s.getSettings)
		protected.PUT("/settings", s.putSettings)
		protected.GET("/projects/:stem/docker-params", s.getDockerParams)
		protected.PATCH("/projects/:stem/docker-params", s.patchDockerParams)
	}

	return r
}

type loginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

func (s *Server) postLogin(c *gin.Context) {
	var req loginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	resp, err := s.auth.Login(c.Request.Context(), req.Username, req.Password)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidCredentials) {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid username or password"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, resp)
}

func (s *Server) getApps(c *gin.Context) {
	rows, err := s.appsSvc.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"apps": rows})
}

type patchAppRequest struct {
	Enabled *bool   `json:"enabled"`
	RunMode *string `json:"runMode"`
}

func (s *Server) patchApp(c *gin.Context) {
	stem := strings.TrimSpace(c.Param("stem"))
	if stem == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "stem required"})
		return
	}
	var req patchAppRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if req.Enabled == nil || req.RunMode == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "enabled and runMode required"})
		return
	}
	update := apps.UpdateRequest{Enabled: req.Enabled}
	mode, err := runmode.Parse(*req.RunMode)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	update.RunMode = &mode
	if err := s.appsSvc.UpdateApp(c.Request.Context(), stem, update); err != nil {
		if strings.Contains(err.Error(), "already in progress") {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	rows, err := s.appsSvc.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"ok": true})
		return
	}
	for _, row := range rows {
		if row.Stem == stem {
			c.JSON(http.StatusOK, row)
			return
		}
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (s *Server) getStacks(c *gin.Context) {
	list, err := s.stacksSvc.List(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"stacks": list})
}

func (s *Server) getStack(c *gin.Context) {
	stem := strings.TrimSpace(c.Param("stem"))
	stack, err := s.stacksSvc.Get(c.Request.Context(), stem)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if stack == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "stack not found"})
		return
	}
	c.JSON(http.StatusOK, stack)
}

func (s *Server) getApplication(c *gin.Context) {
	appID := strings.TrimSpace(c.Param("appId"))
	app, stack, err := s.stacksSvc.GetApplication(c.Request.Context(), appID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if app == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "application not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"application": app, "stack": stack})
}

type postActionRequest struct {
	Stem    string `json:"stem"`
	AppID   string `json:"appId"`
	Channel string `json:"channel"`
	Action  string `json:"action"`
}

func (s *Server) postAction(c *gin.Context) {
	var req postActionRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	channel, err := runmode.Parse(req.Channel)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	action, err := scripts.ParseAction(req.Action)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	job, err := s.actionsSvc.Run(c.Request.Context(), actions.Request{
		Stem:    req.Stem,
		AppID:   req.AppID,
		Channel: channel,
		Action:  action,
	})
	if err != nil {
		if strings.Contains(err.Error(), "already in progress") {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusAccepted, job)
}

func (s *Server) getAction(c *gin.Context) {
	id := strings.TrimSpace(c.Param("id"))
	job, ok := s.actionsSvc.GetJob(id)
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "job not found"})
		return
	}
	c.JSON(http.StatusOK, job)
}

func (s *Server) getSettings(c *gin.Context) {
	settings, err := s.settingsSvc.Get(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, settings)
}

func (s *Server) putSettings(c *gin.Context) {
	var body settings.PlatformSettings
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	if err := s.settingsSvc.Put(c.Request.Context(), body); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, body)
}

func (s *Server) getDockerParams(c *gin.Context) {
	stem := strings.TrimSpace(c.Param("stem"))
	targetRaw := c.DefaultQuery("target", "local")
	target, err := dockerparams.ParseTarget(targetRaw)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	proj, err := discover.FindProjectByStem(s.cfg.GitHubRoot, stem)
	if err != nil || proj == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "stack not found"})
		return
	}
	params, err := dockerparams.Read(proj.PrimaryDir(), target)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"target": target, "params": params})
}

func (s *Server) patchDockerParams(c *gin.Context) {
	stem := strings.TrimSpace(c.Param("stem"))
	targetRaw := c.DefaultQuery("target", "local")
	target, err := dockerparams.ParseTarget(targetRaw)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	var body map[string]string
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
		return
	}
	proj, err := discover.FindProjectByStem(s.cfg.GitHubRoot, stem)
	if err != nil || proj == nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "stack not found"})
		return
	}
	if err := dockerparams.Write(proj.PrimaryDir(), target, body); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	params, _ := dockerparams.Read(proj.PrimaryDir(), target)
	c.JSON(http.StatusOK, gin.H{"target": target, "params": params})
}
