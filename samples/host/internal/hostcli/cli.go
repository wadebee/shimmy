package hostcli

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/wadebee/shimmy/samples/host/internal/hostconfig"
)

var (
	ErrUnsupportedHost = errors.New("unsupported host")
	ErrAWSProfile      = errors.New("aws profiles are not supported")
)

type Options struct {
	EnterpriseConfigFile string
	HomeDir              string
	WorkingDir           string
	Stdout               io.Writer
	Stderr               io.Writer
	Runner               Runner
}

type Runner interface {
	Run(context.Context, Invocation) error
}

type Invocation struct {
	Command []string
	Env     map[string]string
}

type Plan struct {
	Invocations []Invocation
}

func Execute(ctx context.Context, args []string, opts Options) error {
	root := newRootCommand(ctx, opts)
	root.SetArgs(args)

	command, err := root.ExecuteC()
	if err == nil {
		return nil
	}

	if isUsageError(err) {
		command.SetOut(stderr(opts))
		usageErr := command.Usage()
		if usageErr != nil {
			return errors.Join(err, usageErr)
		}
	}

	return err
}

func PlanLogin(effective hostconfig.EffectiveBundle) (Plan, error) {
	if provider := hostconfig.StringValue(effective.Config, "settings", "cloud", "provider"); provider != "aws" {
		return Plan{}, fmt.Errorf("%w: %s", ErrUnsupportedHost, effective.Tuple.System)
	}
	if hostconfig.StringValue(effective.Config, "credentials", "aws", "profile") != "" {
		return Plan{}, ErrAWSProfile
	}

	accessKey := hostconfig.StringValue(effective.Config, "credentials", "aws", "access_key_id")
	secretKey := hostconfig.StringValue(effective.Config, "credentials", "aws", "secret_access_key")
	if accessKey == "" || secretKey == "" {
		return Plan{}, errors.New("aws access key id and secret access key are required")
	}

	return Plan{
		Invocations: []Invocation{
			{
				Command: []string{"aws", "configure", "set", "aws_access_key_id", accessKey},
				Env: map[string]string{
					"AWS_ACCESS_KEY_ID":     accessKey,
					"AWS_SECRET_ACCESS_KEY": secretKey,
				},
			},
			{
				Command: []string{"aws", "configure", "set", "aws_secret_access_key", secretKey},
				Env: map[string]string{
					"AWS_ACCESS_KEY_ID":     accessKey,
					"AWS_SECRET_ACCESS_KEY": secretKey,
				},
			},
		},
	}, nil
}

func PlanWhoami(effective hostconfig.EffectiveBundle) (Plan, error) {
	if provider := hostconfig.StringValue(effective.Config, "settings", "cloud", "provider"); provider != "aws" {
		return Plan{}, fmt.Errorf("%w: %s", ErrUnsupportedHost, effective.Tuple.System)
	}
	if hostconfig.StringValue(effective.Config, "credentials", "aws", "profile") != "" {
		return Plan{}, ErrAWSProfile
	}

	return Plan{
		Invocations: []Invocation{
			{
				Command: []string{"aws", "sts", "get-caller-identity"},
				Env: map[string]string{
					"AWS_ACCESS_KEY_ID":     hostconfig.StringValue(effective.Config, "credentials", "aws", "access_key_id"),
					"AWS_SECRET_ACCESS_KEY": hostconfig.StringValue(effective.Config, "credentials", "aws", "secret_access_key"),
					"AWS_REGION":            hostconfig.StringValue(effective.Config, "settings", "cloud", "region"),
				},
			},
		},
	}, nil
}

type StubRunner struct {
	Writer io.Writer
}

func (runner StubRunner) Run(_ context.Context, invocation Invocation) error {
	writer := runner.Writer
	if writer == nil {
		writer = io.Discard
	}
	_, err := fmt.Fprintf(writer, "stub: %v\n", invocation.Command)
	return err
}

func stdout(opts Options) io.Writer {
	if opts.Stdout != nil {
		return opts.Stdout
	}
	return os.Stdout
}

func workingDir(opts Options) string {
	if opts.WorkingDir != "" {
		return opts.WorkingDir
	}
	return "."
}

func enterpriseConfigFile(opts Options) string {
	return opts.EnterpriseConfigFile
}

type usageError struct {
	err error
}

func (err usageError) Error() string {
	return err.err.Error()
}

func (err usageError) Unwrap() error {
	return err.err
}

func newRootCommand(ctx context.Context, opts Options) *cobra.Command {
	root := &cobra.Command{
		Use:               "host",
		Short:             "Run host workflows through Shimmy shims",
		SilenceErrors:     true,
		SilenceUsage:      true,
		CompletionOptions: cobra.CompletionOptions{DisableDefaultCmd: true},
		RunE: func(_ *cobra.Command, _ []string) error {
			return usageError{err: errors.New("missing command")}
		},
	}
	configureCommand(root, opts)

	root.AddCommand(
		newConfigCommand(opts),
		newPlanCommand(ctx, opts, "login", "Configure cloud credentials from the rendered host config", PlanLogin),
		newPlanCommand(ctx, opts, "whoami", "Show the active cloud identity from the rendered host config", PlanWhoami),
	)

	return root
}

func newConfigCommand(opts Options) *cobra.Command {
	config := &cobra.Command{
		Use:           "config",
		Short:         "Manage host configuration",
		SilenceErrors: true,
		SilenceUsage:  true,
		RunE: func(_ *cobra.Command, _ []string) error {
			return usageError{err: errors.New("missing config command")}
		},
	}
	configureCommand(config, opts)
	config.AddCommand(
		newConfigInitCommand(opts),
		newConfigRenderCommand(opts),
	)
	return config
}

func newConfigInitCommand(opts Options) *cobra.Command {
	tuple := hostconfig.Tuple{}
	command := &cobra.Command{
		Use:           "init",
		Short:         "Create host configuration files",
		SilenceErrors: true,
		SilenceUsage:  true,
		Args:          noArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			if tuple.System == "" {
				return usageError{err: hostconfig.ErrMissingTuple}
			}
			return executeConfigInit(tuple, opts)
		},
	}
	configureCommand(command, opts)
	addTupleFlags(command, &tuple)
	return command
}

func newConfigRenderCommand(opts Options) *cobra.Command {
	tuple := hostconfig.Tuple{}
	command := &cobra.Command{
		Use:           "render",
		Short:         "Render the effective host configuration",
		SilenceErrors: true,
		SilenceUsage:  true,
		Args:          noArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			if tuple.System == "" || tuple.Stage == "" || tuple.Slot == "" {
				return usageError{err: hostconfig.ErrMissingTuple}
			}
			return executeConfigRender(tuple, opts)
		},
	}
	configureCommand(command, opts)
	addTupleFlags(command, &tuple)
	return command
}

func newPlanCommand(ctx context.Context, opts Options, name string, short string, planner func(hostconfig.EffectiveBundle) (Plan, error)) *cobra.Command {
	tuple := hostconfig.Tuple{}
	command := &cobra.Command{
		Use:           name,
		Short:         short,
		SilenceErrors: true,
		SilenceUsage:  true,
		Args:          noArgs,
		RunE: func(_ *cobra.Command, _ []string) error {
			if tuple.System == "" || tuple.Stage == "" || tuple.Slot == "" {
				return usageError{err: hostconfig.ErrMissingTuple}
			}
			effective, err := loadEffectiveBundle(tuple, opts)
			if err != nil {
				return err
			}

			plan, err := planner(effective)
			if err != nil {
				return err
			}

			runner := opts.Runner
			if runner == nil {
				runner = StubRunner{Writer: stdout(opts)}
			}

			for _, invocation := range plan.Invocations {
				if err := runner.Run(ctx, invocation); err != nil {
					return err
				}
			}
			return nil
		},
	}
	configureCommand(command, opts)
	addTupleFlags(command, &tuple)
	return command
}

func configureCommand(command *cobra.Command, opts Options) {
	command.SetOut(stdout(opts))
	command.SetErr(stderr(opts))
	command.SetFlagErrorFunc(func(_ *cobra.Command, err error) error {
		return usageError{err: err}
	})
}

func executeConfigInit(tuple hostconfig.Tuple, opts Options) error {
	result, err := hostconfig.InitConfig(hostconfig.InitOptions{
		EnterpriseFile: enterpriseConfigFile(opts),
		HomeDir:        opts.HomeDir,
		Tuple:          tuple,
		WorkingDir:     workingDir(opts),
	})
	if err != nil {
		return err
	}

	writer := stdout(opts)
	for _, action := range result.Adopted {
		fmt.Fprintf(writer, "Using existing %s defaults: %s\n", action.Role, displayPath(action.Path, opts))
	}
	for _, action := range result.Created {
		fmt.Fprintf(writer, "Created %s: %s\n", action.Role, displayPath(action.Path, opts))
		if action.Role == "enterprise example" {
			fmt.Fprintf(writer, "Install enterprise policy with:\n")
			fmt.Fprintf(writer, "  sudo mkdir -p /etc/host\n")
			fmt.Fprintf(writer, "  sudo cp %s /etc/host/config-enterprise.yaml\n", displayPath(action.Path, opts))
		}
	}
	for _, action := range result.Existing {
		fmt.Fprintf(writer, "Config already exists: %s\n", displayPath(action.Path, opts))
	}

	return nil
}

func executeConfigRender(tuple hostconfig.Tuple, opts Options) error {
	content, err := hostconfig.RenderBundleYAML(hostconfig.RenderOptions{
		EnterpriseFile: enterpriseConfigFile(opts),
		HomeDir:        opts.HomeDir,
		Tuple:          tuple,
		WorkingDir:     workingDir(opts),
	})
	if err != nil {
		return err
	}

	_, err = stdout(opts).Write(content)
	return err
}

func loadEffectiveBundle(tuple hostconfig.Tuple, opts Options) (hostconfig.EffectiveBundle, error) {
	return hostconfig.RenderBundle(hostconfig.RenderOptions{
		EnterpriseFile: enterpriseConfigFile(opts),
		HomeDir:        opts.HomeDir,
		Tuple:          tuple,
		WorkingDir:     workingDir(opts),
	})
}

func addTupleFlags(command *cobra.Command, tuple *hostconfig.Tuple) {
	command.Flags().StringVar(&tuple.System, "system", "", "system slug")
	command.Flags().StringVar(&tuple.Stage, "stage", "", "stage slug")
	command.Flags().StringVar(&tuple.Slot, "slot", "", "slot slug")
}

func noArgs(_ *cobra.Command, args []string) error {
	if len(args) != 0 {
		return usageError{err: fmt.Errorf("unexpected argument %q", args[0])}
	}
	return nil
}

func displayPath(path string, opts Options) string {
	workDir, err := filepath.Abs(workingDir(opts))
	if err != nil {
		return path
	}

	relativePath, err := filepath.Rel(workDir, path)
	if err != nil || relativePath == "." {
		return path
	}
	if relativePath == ".." || strings.HasPrefix(relativePath, "../") {
		return path
	}
	return relativePath
}

func stderr(opts Options) io.Writer {
	if opts.Stderr != nil {
		return opts.Stderr
	}
	return os.Stderr
}

func isUsageError(err error) bool {
	var target usageError
	return errors.As(err, &target)
}
