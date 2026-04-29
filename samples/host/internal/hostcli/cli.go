package hostcli

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

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
	if len(args) == 0 {
		return errors.New("missing command")
	}

	if args[0] == "config" {
		return executeConfig(args[1:], opts)
	}

	effective, err := loadEffectiveBundle(args[1:], opts)
	if err != nil {
		return err
	}

	var plan Plan
	switch args[0] {
	case "login":
		plan, err = PlanLogin(effective)
	case "whoami":
		plan, err = PlanWhoami(effective)
	default:
		err = fmt.Errorf("unknown command %q", args[0])
	}
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

func executeConfig(args []string, opts Options) error {
	if len(args) == 0 {
		return errors.New("missing config command")
	}

	switch args[0] {
	case "init":
		return executeConfigInit(args[1:], opts)
	case "render":
		return executeConfigRender(args[1:], opts)
	default:
		return fmt.Errorf("unknown config command %q", args[0])
	}
}

func executeConfigInit(args []string, opts Options) error {
	tuple, err := parseTupleFlags("host config init", args, opts)
	if err != nil {
		return err
	}

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

func executeConfigRender(args []string, opts Options) error {
	tuple, err := parseTupleFlags("host config render", args, opts)
	if err != nil {
		return err
	}
	if tuple.Stage == "" || tuple.Slot == "" {
		return hostconfig.ErrContextMissing
	}

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

func loadEffectiveBundle(args []string, opts Options) (hostconfig.EffectiveBundle, error) {
	tuple, err := parseTupleFlags("host", args, opts)
	if err != nil {
		return hostconfig.EffectiveBundle{}, err
	}
	if tuple.Stage == "" || tuple.Slot == "" {
		return hostconfig.EffectiveBundle{}, hostconfig.ErrContextMissing
	}

	return hostconfig.RenderBundle(hostconfig.RenderOptions{
		EnterpriseFile: enterpriseConfigFile(opts),
		HomeDir:        opts.HomeDir,
		Tuple:          tuple,
		WorkingDir:     workingDir(opts),
	})
}

func parseTupleFlags(name string, args []string, opts Options) (hostconfig.Tuple, error) {
	flags := flag.NewFlagSet(name, flag.ContinueOnError)
	flags.SetOutput(stderr(opts))

	tuple := hostconfig.Tuple{}
	flags.StringVar(&tuple.System, "system", "", "system slug")
	flags.StringVar(&tuple.Stage, "stage", "", "stage slug")
	flags.StringVar(&tuple.Slot, "slot", "", "slot slug")

	if err := flags.Parse(args); err != nil {
		return hostconfig.Tuple{}, err
	}
	if flags.NArg() != 0 {
		return hostconfig.Tuple{}, fmt.Errorf("unexpected argument %q", flags.Arg(0))
	}

	return tuple, nil
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
