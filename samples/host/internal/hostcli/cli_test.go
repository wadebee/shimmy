package hostcli_test

import (
	"bytes"
	"context"
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	"github.com/wadebee/shimmy/samples/host/internal/hostcli"
	"github.com/wadebee/shimmy/samples/host/internal/hostconfig"
)

func TestExecuteRoot_MissingCommandPrintsUsage(t *testing.T) {
	t.Parallel()

	var stderr bytes.Buffer
	err := hostcli.Execute(context.Background(), nil, hostcli.Options{Stderr: &stderr})
	if err == nil {
		t.Fatal("Execute() error = nil, want error")
	}
	if got := err.Error(); got != "missing command" {
		t.Fatalf("Execute() error = %q, want missing command", got)
	}

	output := stderr.String()
	assertContains(t, output, "Usage:")
	assertContains(t, output, "host [flags]")
	assertContains(t, output, "Available Commands:")
}

func TestExecuteConfig_MissingCommandPrintsUsage(t *testing.T) {
	t.Parallel()

	var stderr bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{"config"}, hostcli.Options{Stderr: &stderr})
	if err == nil {
		t.Fatal("Execute() error = nil, want error")
	}
	if got := err.Error(); got != "missing config command" {
		t.Fatalf("Execute() error = %q, want missing config command", got)
	}

	output := stderr.String()
	assertContains(t, output, "Usage:")
	assertContains(t, output, "host config [flags]")
	assertContains(t, output, "Available Commands:")
	assertContains(t, output, "init")
	assertContains(t, output, "render")
}

func TestExecuteConfigRender_MissingParameterPrintsUsage(t *testing.T) {
	t.Parallel()

	var stderr bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{
		"config",
		"render",
		"--system", "aws",
	}, hostcli.Options{Stderr: &stderr})
	if !errors.Is(err, hostconfig.ErrMissingTuple) {
		t.Fatalf("Execute() error = %v, want %v", err, hostconfig.ErrMissingTuple)
	}

	output := stderr.String()
	assertContains(t, output, "Usage:")
	assertContains(t, output, "host config render [flags]")
	assertContains(t, output, "--stage")
	assertContains(t, output, "--slot")
}

func TestExecuteConfigRender_RuntimeErrorDoesNotPrintUsage(t *testing.T) {
	t.Parallel()

	var stderr bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{
		"config",
		"render",
		"--system", "aws",
		"--stage", "dev",
		"--slot", "1",
	}, hostcli.Options{
		HomeDir:    t.TempDir(),
		WorkingDir: t.TempDir(),
		Stderr:     &stderr,
	})
	if !errors.Is(err, hostconfig.ErrMissingConfig) {
		t.Fatalf("Execute() error = %v, want %v", err, hostconfig.ErrMissingConfig)
	}
	if strings.Contains(stderr.String(), "Usage:") {
		t.Fatalf("unexpected usage output for runtime error:\n%s", stderr.String())
	}
}

func TestExecuteConfigInit_FullyQualifiedCreatesParents(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}

	var stdout bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{
		"config",
		"init",
		"--system", "payments",
		"--stage", "prod",
		"--slot", "blue",
	}, hostcli.Options{
		HomeDir:    home,
		WorkingDir: workDir,
		Stdout:     &stdout,
	})
	if err != nil {
		t.Fatalf("Execute() error = %v", err)
	}

	output := stdout.String()
	assertContains(t, output, "Created user config:")
	assertContains(t, output, "Created enterprise example:")
	assertContains(t, output, "Created system config:")
	assertContains(t, output, "Created stage config:")
	assertContains(t, output, "Created slot config:")
	assertContains(t, output, "sudo cp .config/host/config-enterprise.example.yaml /etc/host/config-enterprise.yaml")
	assertFileExists(t, filepath.Join(workDir, ".config/host/config-sys-payments-stg-prod-slot-blue.yaml"))
}

func TestExecuteConfigInit_AdoptsExistingParentDefaults(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}

	if err := hostcli.Execute(context.Background(), []string{
		"config",
		"init",
		"--system", "payments",
		"--stage", "prod",
		"--slot", "blue",
	}, hostcli.Options{HomeDir: home, WorkingDir: workDir}); err != nil {
		t.Fatalf("first Execute() error = %v", err)
	}

	var stdout bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{
		"config",
		"init",
		"--system", "payments",
		"--stage", "prod",
		"--slot", "green",
	}, hostcli.Options{
		HomeDir:    home,
		WorkingDir: workDir,
		Stdout:     &stdout,
	})
	if err != nil {
		t.Fatalf("second Execute() error = %v", err)
	}

	output := stdout.String()
	assertContains(t, output, "Using existing system config defaults:")
	assertContains(t, output, "Using existing stage config defaults:")
	assertContains(t, output, "Created slot config:")
}

func TestExecuteConfigRender_PrintsEffectiveYAML(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	enterprise := filepath.Join(root, "enterprise.yaml")
	if err := os.MkdirAll(workDir, 0o755); err != nil {
		t.Fatal(err)
	}

	if err := hostcli.Execute(context.Background(), []string{
		"config",
		"init",
		"--system", "payments",
		"--stage", "prod",
		"--slot", "blue",
	}, hostcli.Options{HomeDir: home, WorkingDir: workDir}); err != nil {
		t.Fatalf("init Execute() error = %v", err)
	}
	writeFile(t, enterprise, "settings:\n  logging:\n    retention_days: 365\n")

	var stdout bytes.Buffer
	err := hostcli.Execute(context.Background(), []string{
		"config",
		"render",
		"--system", "payments",
		"--stage", "prod",
		"--slot", "blue",
	}, hostcli.Options{
		EnterpriseConfigFile: enterprise,
		HomeDir:              home,
		WorkingDir:           workDir,
		Stdout:               &stdout,
	})
	if err != nil {
		t.Fatalf("render Execute() error = %v", err)
	}

	output := stdout.String()
	assertContains(t, output, "system: payments")
	assertContains(t, output, "stage: prod")
	assertContains(t, output, "slot: blue")
	assertContains(t, output, "retention_days: 365")
}

func TestPlanWhoami(t *testing.T) {
	t.Parallel()

	plan, err := hostcli.PlanWhoami(hostconfig.EffectiveBundle{
		Tuple: hostconfig.Tuple{System: "aws", Stage: "dev", Slot: "1"},
		Config: map[string]any{
			"settings": map[string]any{
				"cloud": map[string]any{
					"provider": "aws",
					"region":   "us-west-2",
				},
			},
			"credentials": map[string]any{
				"aws": map[string]any{
					"access_key_id":     "key",
					"secret_access_key": "secret",
				},
			},
		},
	})
	if err != nil {
		t.Fatalf("PlanWhoami() error = %v", err)
	}

	wantCommand := []string{"aws", "sts", "get-caller-identity"}
	if !reflect.DeepEqual(plan.Invocations[0].Command, wantCommand) {
		t.Fatalf("PlanWhoami() command = %v, want %v", plan.Invocations[0].Command, wantCommand)
	}
	if got := plan.Invocations[0].Env["AWS_REGION"]; got != "us-west-2" {
		t.Fatalf("AWS_REGION = %q, want us-west-2", got)
	}
}

func TestPlanLogin(t *testing.T) {
	t.Parallel()

	plan, err := hostcli.PlanLogin(hostconfig.EffectiveBundle{
		Tuple: hostconfig.Tuple{System: "aws", Stage: "prod", Slot: "1"},
		Config: map[string]any{
			"settings": map[string]any{
				"cloud": map[string]any{"provider": "aws"},
			},
			"credentials": map[string]any{
				"aws": map[string]any{
					"access_key_id":     "key",
					"secret_access_key": "secret",
				},
			},
		},
	})
	if err != nil {
		t.Fatalf("PlanLogin() error = %v", err)
	}

	if len(plan.Invocations) != 2 {
		t.Fatalf("PlanLogin() invocation count = %d, want 2", len(plan.Invocations))
	}
	if got := plan.Invocations[0].Env["AWS_ACCESS_KEY_ID"]; got != "key" {
		t.Fatalf("AWS_ACCESS_KEY_ID = %q, want key", got)
	}
	if got := plan.Invocations[1].Env["AWS_SECRET_ACCESS_KEY"]; got != "secret" {
		t.Fatalf("AWS_SECRET_ACCESS_KEY = %q, want secret", got)
	}
}

func TestPlanLogin_RejectsAWSProfile(t *testing.T) {
	t.Parallel()

	_, err := hostcli.PlanLogin(hostconfig.EffectiveBundle{
		Tuple: hostconfig.Tuple{System: "aws", Stage: "dev", Slot: "1"},
		Config: map[string]any{
			"settings": map[string]any{
				"cloud": map[string]any{"provider": "aws"},
			},
			"credentials": map[string]any{
				"aws": map[string]any{"profile": "personal"},
			},
		},
	})
	if !errors.Is(err, hostcli.ErrAWSProfile) {
		t.Fatalf("PlanLogin() error = %v, want %v", err, hostcli.ErrAWSProfile)
	}
}

func TestPlanWhoami_RejectsAzureForNow(t *testing.T) {
	t.Parallel()

	_, err := hostcli.PlanWhoami(hostconfig.EffectiveBundle{
		Tuple: hostconfig.Tuple{System: "azure", Stage: "dev", Slot: "1"},
		Config: map[string]any{
			"settings": map[string]any{
				"cloud": map[string]any{"provider": "azure"},
			},
		},
	})
	if !errors.Is(err, hostcli.ErrUnsupportedHost) {
		t.Fatalf("PlanWhoami() error = %v, want %v", err, hostcli.ErrUnsupportedHost)
	}
}

func TestExecuteWhoami_UsesRenderedSlotConfig(t *testing.T) {
	t.Parallel()

	root := t.TempDir()
	home := filepath.Join(root, "home")
	workDir := filepath.Join(root, "repo")
	configDir := filepath.Join(workDir, hostconfig.RepoConfigDir)
	if err := os.MkdirAll(configDir, 0o755); err != nil {
		t.Fatal(err)
	}
	writeFile(t, filepath.Join(configDir, "config-sys-aws.yaml"), `
settings:
  cloud:
    provider: aws
    region: us-east-1
credentials:
  aws:
    access_key_id: key
    secret_access_key: secret
`)
	writeFile(t, filepath.Join(configDir, "config-sys-aws-stg-dev.yaml"), `
settings:
  cloud:
    region: us-west-2
`)
	writeFile(t, filepath.Join(configDir, "config-sys-aws-stg-dev-slot-1.yaml"), `
metadata:
  labels:
    slot: "1"
`)

	runner := &recordingRunner{}
	err := hostcli.Execute(context.Background(), []string{
		"whoami",
		"--system", "aws",
		"--stage", "dev",
		"--slot", "1",
	}, hostcli.Options{
		HomeDir:    home,
		WorkingDir: workDir,
		Runner:     runner,
	})
	if err != nil {
		t.Fatalf("Execute() error = %v", err)
	}

	wantCommand := []string{"aws", "sts", "get-caller-identity"}
	if !reflect.DeepEqual(runner.invocation.Command, wantCommand) {
		t.Fatalf("executed command = %v, want %v", runner.invocation.Command, wantCommand)
	}
	if got := runner.invocation.Env["AWS_REGION"]; got != "us-west-2" {
		t.Fatalf("AWS_REGION = %q, want us-west-2", got)
	}
}

type recordingRunner struct {
	invocation hostcli.Invocation
}

func (runner *recordingRunner) Run(_ context.Context, invocation hostcli.Invocation) error {
	runner.invocation = invocation
	return nil
}

func assertContains(t *testing.T, haystack string, needle string) {
	t.Helper()
	if !bytes.Contains([]byte(haystack), []byte(needle)) {
		t.Fatalf("expected output to contain %q; got:\n%s", needle, haystack)
	}
}

func assertFileExists(t *testing.T, path string) {
	t.Helper()
	if _, err := os.Stat(path); err != nil {
		t.Fatalf("expected file to exist: %s: %v", path, err)
	}
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
