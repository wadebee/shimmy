package hostconfig_test

import (
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/wadebee/shimmy/samples/host/internal/hostconfig"
)

func TestInitConfig_FullyQualifiedCreatesParents(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}

	result, err := hostconfig.InitConfig(hostconfig.InitOptions{
		HomeDir:    home,
		Tuple:      hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "blue"},
		WorkingDir: workDir,
	})
	if err != nil {
		t.Fatalf("InitConfig() error = %v", err)
	}

	assertCreatedRole(t, result, "user config")
	assertCreatedRole(t, result, "enterprise example")
	assertCreatedRole(t, result, "system config")
	assertCreatedRole(t, result, "stage config")
	assertCreatedRole(t, result, "slot config")
	assertFileExists(t, filepath.Join(home, ".config/host/config-user.yaml"))
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-enterprise.example.yaml"))
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-sys-payments.yaml"))
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-sys-payments-stg-prod.yaml"))
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-sys-payments-stg-prod-slot-blue.yaml"))
}

func TestInitConfig_AdoptsExistingParents(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}

	_, err := hostconfig.InitConfig(hostconfig.InitOptions{
		HomeDir:    home,
		Tuple:      hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "blue"},
		WorkingDir: workDir,
	})
	if err != nil {
		t.Fatalf("InitConfig() first run error = %v", err)
	}

	result, err := hostconfig.InitConfig(hostconfig.InitOptions{
		HomeDir:    home,
		Tuple:      hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "green"},
		WorkingDir: workDir,
	})
	if err != nil {
		t.Fatalf("InitConfig() second run error = %v", err)
	}

	assertAdoptedRole(t, result, "user config")
	assertAdoptedRole(t, result, "system config")
	assertAdoptedRole(t, result, "stage config")
	assertCreatedRole(t, result, "slot config")
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-sys-payments-stg-prod-slot-green.yaml"))
}

func TestInitConfig_DoesNotOverwriteExistingTarget(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(filepath.Join(workDir, ".config/host"), 0o755); err != nil {
		t.Fatal(err)
	}

	target := filepath.Join(workDir, ".config/host/config-sys-payments.yaml")
	if err := os.WriteFile(target, []byte("metadata:\n  labels:\n    owner: custom\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	result, err := hostconfig.InitConfig(hostconfig.InitOptions{
		HomeDir:    home,
		Tuple:      hostconfig.Tuple{System: "payments"},
		WorkingDir: workDir,
	})
	if err != nil {
		t.Fatalf("InitConfig() error = %v", err)
	}

	assertExistingRole(t, result, "system config")
	content, err := os.ReadFile(target)
	if err != nil {
		t.Fatal(err)
	}
	if got := string(content); got != "metadata:\n  labels:\n    owner: custom\n" {
		t.Fatalf("target content was overwritten: %q", got)
	}
}

func TestValidateSlug(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name      string
		tuple     hostconfig.Tuple
		wantError bool
	}{
		{
			name:  "named slot",
			tuple: hostconfig.Tuple{System: "payments-api", Stage: "prod", Slot: "blue"},
		},
		{
			name:  "numeric slot",
			tuple: hostconfig.Tuple{System: "payments-api", Stage: "prod", Slot: "1"},
		},
		{
			name:      "uppercase system",
			tuple:     hostconfig.Tuple{System: "Payments"},
			wantError: true,
		},
		{
			name:      "system too long",
			tuple:     hostconfig.Tuple{System: "this-system-name-is-too-long"},
			wantError: true,
		},
		{
			name:      "stage too long",
			tuple:     hostconfig.Tuple{System: "payments", Stage: "developmentxx"},
			wantError: true,
		},
		{
			name:      "slot too long",
			tuple:     hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "primary-green"},
			wantError: true,
		},
		{
			name:      "slot without stage",
			tuple:     hostconfig.Tuple{System: "payments", Slot: "1"},
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := hostconfig.ValidateTuple(tt.tuple)
			if tt.wantError && err == nil {
				t.Fatal("ValidateTuple() error = nil, want error")
			}
			if !tt.wantError && err != nil {
				t.Fatalf("ValidateTuple() error = %v", err)
			}
		})
	}
}

func TestFindRepoConfigDir(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	project := filepath.Join(root, "project")
	nested := filepath.Join(project, "service")
	configDir := filepath.Join(project, hostconfig.RepoConfigDir)
	if err := os.MkdirAll(nested, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}

	got, err := hostconfig.FindRepoConfigDir(nested)
	if err != nil {
		t.Fatalf("FindRepoConfigDir() error = %v", err)
	}
	if got != configDir {
		t.Fatalf("FindRepoConfigDir() = %q, want %q", got, configDir)
	}
}

func TestFindRepoConfigDir_NotFound(t *testing.T) {
	t.Parallel()

	_, err := hostconfig.FindRepoConfigDir(t.TempDir())
	if !errors.Is(err, hostconfig.ErrConfigNotFound) {
		t.Fatalf("FindRepoConfigDir() error = %v, want %v", err, hostconfig.ErrConfigNotFound)
	}
}

func TestRenderBundle_MergesConfigHierarchy(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	enterprise := filepath.Join(root, "enterprise.yaml")
	configDir := filepath.Join(workDir, hostconfig.RepoConfigDir)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(filepath.Join(home, ".config/host/config-user.yaml")), 0o755); err != nil {
		t.Fatal(err)
	}

	writeFile(t, enterprise, `
settings:
  logging:
    retention_days: 365
  cloud:
    region: us-east-2
dependencies:
  registries:
    - public.ecr.aws
`)
	writeFile(t, filepath.Join(home, ".config/host/config-user.yaml"), `
settings:
  cloud:
    provider: aws
    region: us-west-1
  logging:
    level: info
dependencies:
  registries:
    - docker.io
`)
	writeFile(t, filepath.Join(configDir, "config-sys-payments.yaml"), `
settings:
  cloud:
    region: us-east-1
  logging:
    level: debug
    format: text
dependencies:
  tools:
    aws:
      image: public.ecr.aws/aws-cli/aws-cli:2.31.21
`)
	writeFile(t, filepath.Join(configDir, "config-sys-payments-stg-prod.yaml"), `
settings:
  logging:
    level: warn
dependencies:
  registries:
    - ghcr.io
`)
	writeFile(t, filepath.Join(configDir, "config-sys-payments-stg-prod-slot-blue.yaml"), `
settings:
  logging:
    format: null
  instance:
    replicas: 3
dependencies:
  tools: null
`)

	bundle, err := hostconfig.RenderBundle(hostconfig.RenderOptions{
		EnterpriseFile: enterprise,
		HomeDir:        home,
		Tuple:          hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "blue"},
		WorkingDir:     filepath.Join(workDir, "nested"),
	})
	if err != nil {
		t.Fatalf("RenderBundle() error = %v", err)
	}

	assertStringValue(t, bundle.Config, "aws", "settings", "cloud", "provider")
	assertStringValue(t, bundle.Config, "us-east-2", "settings", "cloud", "region")
	assertStringValue(t, bundle.Config, "warn", "settings", "logging", "level")
	assertStringValue(t, bundle.Config, "365", "settings", "logging", "retention_days")
	assertStringValue(t, bundle.Config, "3", "settings", "instance", "replicas")
	assertMissingValue(t, bundle.Config, "settings", "logging", "format")
	assertMissingValue(t, bundle.Config, "dependencies", "tools")

	registries := valueAt(t, bundle.Config, "dependencies", "registries")
	gotRegistries, ok := registries.([]any)
	if !ok {
		t.Fatalf("dependencies.registries type = %T, want []any", registries)
	}
	if len(gotRegistries) != 1 || gotRegistries[0] != "public.ecr.aws" {
		t.Fatalf("dependencies.registries = %#v, want enterprise replacement", gotRegistries)
	}
}

func TestRenderBundle_RequiresYAMLConfig(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(workDir, ".host.json"), []byte(`{"hosts":{}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	_, err := hostconfig.RenderBundle(hostconfig.RenderOptions{
		HomeDir:    filepath.Join(root, "home"),
		Tuple:      hostconfig.Tuple{System: "payments", Stage: "prod", Slot: "blue"},
		WorkingDir: workDir,
	})
	if !errors.Is(err, hostconfig.ErrConfigNotFound) {
		t.Fatalf("RenderBundle() error = %v, want %v", err, hostconfig.ErrConfigNotFound)
	}
}

func assertAdoptedRole(t *testing.T, result hostconfig.InitResult, role string) {
	t.Helper()
	assertRole(t, result.Adopted, role, "adopted")
}

func assertCreatedRole(t *testing.T, result hostconfig.InitResult, role string) {
	t.Helper()
	assertRole(t, result.Created, role, "created")
}

func assertExistingRole(t *testing.T, result hostconfig.InitResult, role string) {
	t.Helper()
	assertRole(t, result.Existing, role, "existing")
}

func assertFileExists(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected file to exist: %s: %v", path, err)
	}
}

func assertMissingValue(t *testing.T, config map[string]any, path ...string) {
	t.Helper()
	if got := hostconfig.StringValue(config, path...); got != "" {
		t.Fatalf("%v = %q, want missing", path, got)
	}
}

func assertRole(t *testing.T, actions []hostconfig.FileAction, role string, actionName string) {
	t.Helper()
	for _, action := range actions {
		if action.Role == role {
			return
		}
	}
	t.Fatalf("%s actions missing role %q: %#v", actionName, role, actions)
}

func assertStringValue(t *testing.T, config map[string]any, want string, path ...string) {
	t.Helper()
	if got := hostconfig.StringValue(config, path...); got != want {
		t.Fatalf("%v = %q, want %q", path, got, want)
	}
}

func valueAt(t *testing.T, config map[string]any, path ...string) any {
	t.Helper()

	var current any = config
	for _, token := range path {
		currentMap, ok := current.(map[string]any)
		if !ok {
			t.Fatalf("%v parent type = %T, want map[string]any", path, current)
		}
		current = currentMap[token]
	}
	return current
}

func writeFile(t *testing.T, path string, content string) {
	t.Helper()

	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
}
