package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ArminDashti/devmin-api/internal/actions"
	"github.com/ArminDashti/devmin-api/internal/apps"
	"github.com/ArminDashti/devmin-api/internal/auth"
	"github.com/ArminDashti/devmin-api/internal/config"
	httpserver "github.com/ArminDashti/devmin-api/internal/http"
	"github.com/ArminDashti/devmin-api/internal/runner"
	"github.com/ArminDashti/devmin-api/internal/scripts"
	"github.com/ArminDashti/devmin-api/internal/settings"
	"github.com/ArminDashti/devmin-api/internal/stacks"
	"github.com/ArminDashti/devmin-api/internal/store"
	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()
	cfg := config.Load()

	ctx := context.Background()
	db, err := store.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("postgres required: %v", err)
	}
	defer db.Close()

	authSvc := auth.NewService(db, cfg.JWTSecret)
	if err := authSvc.EnsureDefaultUser(ctx, cfg.DefaultUsername, cfg.DefaultPassword); err != nil {
		log.Fatalf("seed default user: %v", err)
	}

	flight := runner.NewFlight()
	hotReload := runner.NewNativeRunner(cfg.NativeRunnerScript, cfg.NativeAppsConfig, cfg.NativeHotReloadScript)
	localNative := runner.NewNativeRunner(cfg.NativeRunnerScript, cfg.NativeAppsConfig, "")
	localDocker := runner.NewDockerRunner(cfg.DockerRunnerScript, cfg.GitHubRoot)
	serverDocker := runner.NewServerRunner()
	bareServer := runner.NewBareServerRunner()
	router := runner.NewRouter(hotReload, localNative, localDocker, serverDocker, bareServer, flight)

	appsSvc := apps.NewService(cfg, db, router)
	stacksSvc := stacks.NewService(cfg, db)
	jobMgr := scripts.NewJobManager()
	invoker := scripts.NewInvoker(jobMgr)
	resolver := scripts.NewResolver(cfg)
	actionsSvc := actions.NewService(cfg, db, router, resolver, invoker)
	settingsSvc := settings.NewService(cfg, db)

	srv := httpserver.New(cfg, authSvc, appsSvc, stacksSvc, actionsSvc, settingsSvc)

	httpServer := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           srv.Router(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("devmin-api listening on http://%s", cfg.HTTPAddr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("server error: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(shutdownCtx)
}
