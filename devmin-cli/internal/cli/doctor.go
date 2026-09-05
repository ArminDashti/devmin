package cli

import (
	"fmt"

	"github.com/spf13/cobra"

	"github.com/ArminDashti/devmin-cli/internal/api"
	"github.com/ArminDashti/devmin-cli/internal/config"
	"github.com/ArminDashti/devmin-cli/internal/resolve"
	"github.com/ArminDashti/devmin-cli/internal/ui"
)

var doctorCmd = &cobra.Command{
	Use:   "doctor",
	Short: "Check API health, auth, and stack discovery",
	RunE: func(cmd *cobra.Command, args []string) error {
		ctx, cancel := withTimeout()
		defer cancel()

		cfg = config.Load()
		cfg.JSON = jsonOutput
		apiClient = apiClientOrNew()

		type check struct {
			Name    string `json:"name"`
			OK      bool   `json:"ok"`
			Detail  string `json:"detail"`
		}
		checks := make([]check, 0, 4)

		health, err := apiClient.Health(ctx)
		ok := err == nil && health != nil && health.Status == "ok"
		detail := cfg.APIURL
		if err != nil {
			detail = err.Error()
		} else if health != nil {
			detail = fmt.Sprintf("%s → %s", cfg.APIURL, health.Status)
		}
		checks = append(checks, check{Name: "api /health", OK: ok, Detail: detail})

		authOK := false
		authDetail := cfg.Username
		if err := apiClient.EnsureAuth(ctx, cfg.Username, cfg.Password); err != nil {
			authDetail = err.Error()
		} else {
			authOK = true
			authDetail = "token ready (" + cfg.Username + ")"
		}
		checks = append(checks, check{Name: "auth", OK: authOK, Detail: authDetail})

		stackOK := false
		stackDetail := ""
		appCount := 0
		online := 0
		if authOK {
			stacks, err := apiClient.ListStacks(ctx)
			if err != nil {
				stackDetail = err.Error()
			} else {
				stackOK = true
				apps := resolve.FlattenApps(stacks)
				appCount = len(apps)
				for _, a := range apps {
					if resolve.AppIsOnline(a) {
						online++
					}
				}
				stackDetail = fmt.Sprintf("%d stacks · %d apps · %d online", len(stacks), appCount, online)
			}
		} else {
			stackDetail = "skipped (auth failed)"
		}
		checks = append(checks, check{Name: "stacks", OK: stackOK, Detail: stackDetail})

		if jsonOutput {
			return printJSON(map[string]any{
				"version": config.Version,
				"checks":  checks,
			})
		}

		fmt.Println(ui.Banner(config.Version))
		fmt.Println()
		fmt.Println(ui.TitleStyle.Render("◆ doctor"))
		fmt.Println()
		allOK := true
		for _, c := range checks {
			fmt.Println(ui.CheckLine(c.OK, c.Name, c.Detail))
			if !c.OK {
				allOK = false
			}
		}
		fmt.Println()
		if allOK {
			ui.Okf("system looks healthy")
			return nil
		}
		ui.Errf("doctor found problems")
		return fmt.Errorf("doctor failed")
	},
}

func apiClientOrNew() *api.Client {
	if apiClient != nil {
		return apiClient
	}
	cfg = config.Load()
	apiClient = api.NewClient(cfg.APIURL, cfg.TokenPath())
	return apiClient
}
