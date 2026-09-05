package cli

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"

	"github.com/ArminDashti/devmin-cli/internal/api"
	"github.com/ArminDashti/devmin-cli/internal/config"
	"github.com/ArminDashti/devmin-cli/internal/ui"
)

var (
	cfg        config.Config
	apiClient  *api.Client
	jsonOutput bool
)

func Execute() error {
	return rootCmd.Execute()
}

var rootCmd = &cobra.Command{
	Use:   "devmin",
	Short: "Devmin ops CLI — doctor, lists, deploy",
	Long: `Geek-loved terminal for stack ops against a running devmin-api.

Env:
  DEVMIN_API_URL     default http://127.0.0.1:8195
  DEVMIN_USERNAME    login user
  DEVMIN_PASSWORD    login password
`,
	SilenceUsage:  true,
	SilenceErrors: true,
	RunE: func(cmd *cobra.Command, args []string) error {
		fmt.Println(ui.Banner(config.Version))
		fmt.Println()
		fmt.Println(ui.DimStyle.Render("Try:  devmin help   ·   devmin doctor   ·   devmin app online-offline list"))
		return nil
	},
}

func init() {
	rootCmd.PersistentFlags().BoolVar(&jsonOutput, "json", false, "emit JSON instead of tables")
	rootCmd.SetHelpCommand(&cobra.Command{
		Use:   "help [command]",
		Short: "Help about any command",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println(ui.Banner(config.Version))
			fmt.Println()
			_ = rootCmd.Help()
		},
	})
	rootCmd.AddCommand(doctorCmd)
	rootCmd.AddCommand(newAppCmd())
}

func ensureAPI(ctx context.Context) error {
	if apiClient == nil {
		cfg = config.Load()
		cfg.JSON = jsonOutput
		apiClient = api.NewClient(cfg.APIURL, cfg.TokenPath())
	}
	if err := apiClient.EnsureAuth(ctx, cfg.Username, cfg.Password); err != nil {
		return fmt.Errorf("auth against %s: %w", cfg.APIURL, err)
	}
	return nil
}

func printJSON(v any) error {
	enc := json.NewEncoder(os.Stdout)
	enc.SetIndent("", "  ")
	return enc.Encode(v)
}

func withTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 10*time.Minute)
}
