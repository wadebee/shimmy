package hostconfig

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"

	"gopkg.in/yaml.v3"
)

const (
	EnterpriseConfigPath        = "/etc/host/config-enterprise.yaml"
	EnterpriseExampleFileName   = "config-enterprise.example.yaml"
	RepoConfigDir               = ".config/host"
	SystemSlugMaxLength         = 24
	StageSlugMaxLength          = 12
	SlotSlugMaxLength           = 12
	UserConfigFileName          = "config-user.yaml"
	UserConfigRelativeDirectory = ".config/host"
)

var (
	ErrConfigNotFound = errors.New("host config not found")
	ErrContextMissing = errors.New("host context missing")
	ErrInvalidSlug    = errors.New("invalid slug")

	slugPattern = regexp.MustCompile(`^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$`)
)

type EffectiveBundle struct {
	Tuple  Tuple
	Config map[string]any
}

type FileAction struct {
	Role string
	Path string
}

type InitOptions struct {
	EnterpriseFile string
	HomeDir        string
	Tuple          Tuple
	WorkingDir     string
}

type InitResult struct {
	Adopted  []FileAction
	Created  []FileAction
	Existing []FileAction
}

type Paths struct {
	EnterpriseConfigFile string
	RepoConfigDir        string
	UserConfigFile       string
}

type RenderOptions struct {
	EnterpriseFile string
	HomeDir        string
	Tuple          Tuple
	WorkingDir     string
}

type Tuple struct {
	System string
	Stage  string
	Slot   string
}

func InitConfig(opts InitOptions) (InitResult, error) {
	if err := ValidateTuple(opts.Tuple); err != nil {
		return InitResult{}, err
	}

	paths, err := PathsForInit(opts.WorkingDir, opts.HomeDir, opts.EnterpriseFile)
	if err != nil {
		return InitResult{}, err
	}

	entries := initEntries(opts.Tuple, paths)
	result := InitResult{
		Adopted:  []FileAction{},
		Created:  []FileAction{},
		Existing: []FileAction{},
	}
	targetPath := entries[len(entries)-1].Path

	for _, entry := range entries {
		exists, err := pathExists(entry.Path)
		if err != nil {
			return InitResult{}, err
		}
		action := FileAction{Role: entry.Role, Path: entry.Path}
		if exists {
			if entry.Path == targetPath {
				result.Existing = append(result.Existing, action)
			} else if entry.Adoptable {
				result.Adopted = append(result.Adopted, action)
			}
			continue
		}

		if err := os.MkdirAll(filepath.Dir(entry.Path), 0o755); err != nil {
			return InitResult{}, err
		}
		if err := os.WriteFile(entry.Path, []byte(entry.Content), 0o644); err != nil {
			return InitResult{}, err
		}
		result.Created = append(result.Created, action)
	}

	return result, nil
}

func PathsForInit(workingDir string, homeDir string, enterpriseFile string) (Paths, error) {
	root, err := absoluteDir(defaultString(workingDir, "."))
	if err != nil {
		return Paths{}, err
	}

	home, err := resolveHomeDir(homeDir)
	if err != nil {
		return Paths{}, err
	}

	return Paths{
		EnterpriseConfigFile: defaultString(enterpriseFile, EnterpriseConfigPath),
		RepoConfigDir:        filepath.Join(root, RepoConfigDir),
		UserConfigFile:       filepath.Join(home, UserConfigRelativeDirectory, UserConfigFileName),
	}, nil
}

func PathsForRender(workingDir string, homeDir string, enterpriseFile string) (Paths, error) {
	repoConfigDir, err := FindRepoConfigDir(defaultString(workingDir, "."))
	if err != nil {
		return Paths{}, err
	}

	home, err := resolveHomeDir(homeDir)
	if err != nil {
		return Paths{}, err
	}

	return Paths{
		EnterpriseConfigFile: defaultString(enterpriseFile, EnterpriseConfigPath),
		RepoConfigDir:        repoConfigDir,
		UserConfigFile:       filepath.Join(home, UserConfigRelativeDirectory, UserConfigFileName),
	}, nil
}

func RenderBundle(opts RenderOptions) (EffectiveBundle, error) {
	if err := ValidateRenderTuple(opts.Tuple); err != nil {
		return EffectiveBundle{}, err
	}

	paths, err := PathsForRender(opts.WorkingDir, opts.HomeDir, opts.EnterpriseFile)
	if err != nil {
		return EffectiveBundle{}, err
	}

	enterpriseConfig, err := loadOptionalYAML(paths.EnterpriseConfigFile)
	if err != nil {
		return EffectiveBundle{}, err
	}

	effective := map[string]any{}
	MergeInto(effective, enterpriseConfig)

	for _, path := range []string{
		paths.UserConfigFile,
		filepath.Join(paths.RepoConfigDir, SystemConfigFileName(opts.Tuple.System)),
		filepath.Join(paths.RepoConfigDir, StageConfigFileName(opts.Tuple.System, opts.Tuple.Stage)),
		filepath.Join(paths.RepoConfigDir, SlotConfigFileName(opts.Tuple.System, opts.Tuple.Stage, opts.Tuple.Slot)),
	} {
		layer, err := LoadYAMLFile(path)
		if err != nil {
			if path == paths.UserConfigFile && errors.Is(err, os.ErrNotExist) {
				continue
			}
			return EffectiveBundle{}, err
		}
		MergeInto(effective, layer)
	}

	MergeInto(effective, enterpriseConfig)

	return EffectiveBundle{
		Tuple:  opts.Tuple,
		Config: effective,
	}, nil
}

func RenderBundleYAML(opts RenderOptions) ([]byte, error) {
	bundle, err := RenderBundle(opts)
	if err != nil {
		return nil, err
	}

	return yaml.Marshal(bundle.Config)
}

func FindRepoConfigDir(startDir string) (string, error) {
	dir, err := absoluteDir(startDir)
	if err != nil {
		return "", err
	}

	for {
		candidate := filepath.Join(dir, RepoConfigDir)
		info, err := os.Stat(candidate)
		if err == nil && info.IsDir() {
			return candidate, nil
		}
		if err != nil && !errors.Is(err, os.ErrNotExist) {
			return "", err
		}

		parent := filepath.Dir(dir)
		if parent == dir {
			return "", ErrConfigNotFound
		}
		dir = parent
	}
}

func LoadYAMLFile(path string) (map[string]any, error) {
	content, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	config := map[string]any{}
	if err := yaml.Unmarshal(content, &config); err != nil {
		return nil, fmt.Errorf("parse yaml %s: %w", path, err)
	}
	if config == nil {
		return map[string]any{}, nil
	}

	return config, nil
}

func MergeInto(dst map[string]any, src map[string]any) {
	for key, srcValue := range src {
		if srcValue == nil {
			delete(dst, key)
			continue
		}

		srcMap, srcIsMap := asStringMap(srcValue)
		dstMap, dstIsMap := asStringMap(dst[key])
		if srcIsMap && dstIsMap {
			MergeInto(dstMap, srcMap)
			dst[key] = dstMap
			continue
		}

		dst[key] = cloneValue(srcValue)
	}
}

func StringValue(config map[string]any, path ...string) string {
	var current any = config
	for _, token := range path {
		currentMap, ok := asStringMap(current)
		if !ok {
			return ""
		}
		current = currentMap[token]
	}

	switch value := current.(type) {
	case string:
		return value
	case int:
		return strconv.Itoa(value)
	case int64:
		return strconv.FormatInt(value, 10)
	case float64:
		return strconv.FormatFloat(value, 'f', -1, 64)
	case bool:
		return strconv.FormatBool(value)
	default:
		return ""
	}
}

func SystemConfigFileName(system string) string {
	return fmt.Sprintf("config-sys-%s.yaml", system)
}

func StageConfigFileName(system string, stage string) string {
	return fmt.Sprintf("config-sys-%s-stg-%s.yaml", system, stage)
}

func SlotConfigFileName(system string, stage string, slot string) string {
	return fmt.Sprintf("config-sys-%s-stg-%s-slot-%s.yaml", system, stage, slot)
}

func ValidateRenderTuple(tuple Tuple) error {
	if tuple.System == "" || tuple.Stage == "" || tuple.Slot == "" {
		return ErrContextMissing
	}

	return ValidateTuple(tuple)
}

func ValidateSlug(kind string, slug string, maxLength int) error {
	if slug == "" {
		return fmt.Errorf("%w: %s slug is required", ErrInvalidSlug, kind)
	}
	if len(slug) > maxLength {
		return fmt.Errorf("%w: %s slug %q exceeds %d characters", ErrInvalidSlug, kind, slug, maxLength)
	}
	if !slugPattern.MatchString(slug) {
		return fmt.Errorf("%w: %s slug %q must use lowercase letters, numbers, and hyphens without leading or trailing hyphens", ErrInvalidSlug, kind, slug)
	}

	return nil
}

func ValidateTuple(tuple Tuple) error {
	if tuple.System == "" {
		return ErrContextMissing
	}
	if tuple.Slot != "" && tuple.Stage == "" {
		return ErrContextMissing
	}
	if err := ValidateSlug("system", tuple.System, SystemSlugMaxLength); err != nil {
		return err
	}
	if tuple.Stage != "" {
		if err := ValidateSlug("stage", tuple.Stage, StageSlugMaxLength); err != nil {
			return err
		}
	}
	if tuple.Slot != "" {
		if err := ValidateSlug("slot", tuple.Slot, SlotSlugMaxLength); err != nil {
			return err
		}
	}

	return nil
}

type initEntry struct {
	Adoptable bool
	Content   string
	Path      string
	Role      string
}

func EnterpriseExampleTemplate() string {
	return `# Enterprise configuration example.
# Copy this file to /etc/host/config-enterprise.yaml to enable governance policy.
# Enterprise settings apply to every system, stage, and slot. Lower-level config
# cannot override or remove uncommented enterprise values, including with null.
#
# metadata:
#   labels:
#     governance: enterprise
# policies:
#   logging:
#     structured: true
#     retention_days: 365
#     applies_to:
#       labels:
#         stage: prod
# dependencies:
#   allowed_registries:
#     - public.ecr.aws
#     - docker.io
`
}

func StageConfigTemplate(system string, stage string) string {
	region := "us-west-2"
	logLevel := "debug"
	approvalRequired := "false"
	if stage == "prod" {
		region = "us-east-1"
		logLevel = "info"
		approvalRequired = "true"
	}

	return fmt.Sprintf(`# Stage configuration for system %q, stage %q.
# These inherited defaults apply to slots under this stage. Slot config may
# override or remove these values with null unless enterprise policy owns them.
metadata:
  tuple:
    system: %q
    stage: %q
  labels:
    system: %q
    stage: %q
    lifecycle: %q
settings:
  cloud:
    region: %q
  logging:
    level: %q
policies:
  deployment:
    approval_required: %s
`, system, stage, system, stage, system, stage, stage, region, logLevel, approvalRequired)
}

func SlotConfigTemplate(system string, stage string, slot string) string {
	return fmt.Sprintf(`# Slot configuration for system %q, stage %q, slot %q.
# This is the most specific auditable deployment bundle. It may override user,
# system, and stage defaults, but it cannot override enterprise policy.
metadata:
  tuple:
    system: %q
    stage: %q
    slot: %q
  labels:
    system: %q
    stage: %q
    slot: %q
    bundle: %q
settings:
  instance:
    identity: %q
    replicas: 1
dependencies:
  artifacts: []
`, system, stage, slot, system, stage, slot, system, stage, slot, system+"-"+stage+"-"+slot, slot)
}

func SystemConfigTemplate(system string) string {
	return fmt.Sprintf(`# System configuration for system %q.
# These inherited defaults apply to all stages and slots for this system.
# Lower-level config may override or remove these values with null unless
# enterprise policy owns them.
metadata:
  tuple:
    system: %q
  labels:
    system: %q
    owner: platform-team
settings:
  cloud:
    provider: aws
    region: us-east-1
  logging:
    level: info
dependencies:
  tools:
    aws:
      image: public.ecr.aws/aws-cli/aws-cli:2.31.21
policies:
  deployment:
    approval_required: false
`, system, system, system)
}

func UserConfigTemplate() string {
	return `# User configuration.
# These personal defaults apply to all repositories for this user. System,
# stage, and slot config may override or remove them with null.
metadata:
  labels:
    scope: user
settings:
  cli:
    output: text
  logging:
    level: info
`
}

func absoluteDir(path string) (string, error) {
	return filepath.Abs(defaultString(path, "."))
}

func asStringMap(value any) (map[string]any, bool) {
	switch typed := value.(type) {
	case map[string]any:
		return typed, true
	default:
		return nil, false
	}
}

func cloneValue(value any) any {
	if valueMap, ok := asStringMap(value); ok {
		clone := make(map[string]any, len(valueMap))
		for key, nestedValue := range valueMap {
			clone[key] = cloneValue(nestedValue)
		}
		return clone
	}

	valueSlice, ok := value.([]any)
	if !ok {
		return value
	}

	clone := make([]any, len(valueSlice))
	for i, nestedValue := range valueSlice {
		clone[i] = cloneValue(nestedValue)
	}
	return clone
}

func defaultString(value string, fallback string) string {
	if value != "" {
		return value
	}
	return fallback
}

func initEntries(tuple Tuple, paths Paths) []initEntry {
	entries := []initEntry{
		{
			Adoptable: true,
			Content:   UserConfigTemplate(),
			Path:      paths.UserConfigFile,
			Role:      "user config",
		},
		{
			Content: EnterpriseExampleTemplate(),
			Path:    filepath.Join(paths.RepoConfigDir, EnterpriseExampleFileName),
			Role:    "enterprise example",
		},
		{
			Adoptable: true,
			Content:   SystemConfigTemplate(tuple.System),
			Path:      filepath.Join(paths.RepoConfigDir, SystemConfigFileName(tuple.System)),
			Role:      "system config",
		},
	}

	if tuple.Stage == "" {
		return entries
	}

	entries = append(entries, initEntry{
		Adoptable: true,
		Content:   StageConfigTemplate(tuple.System, tuple.Stage),
		Path:      filepath.Join(paths.RepoConfigDir, StageConfigFileName(tuple.System, tuple.Stage)),
		Role:      "stage config",
	})

	if tuple.Slot == "" {
		return entries
	}

	return append(entries, initEntry{
		Content: SlotConfigTemplate(tuple.System, tuple.Stage, tuple.Slot),
		Path:    filepath.Join(paths.RepoConfigDir, SlotConfigFileName(tuple.System, tuple.Stage, tuple.Slot)),
		Role:    "slot config",
	})
}

func loadOptionalYAML(path string) (map[string]any, error) {
	config, err := LoadYAMLFile(path)
	if err == nil {
		return config, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return map[string]any{}, nil
	}
	return nil, err
}

func pathExists(path string) (bool, error) {
	_, err := os.Stat(path)
	if err == nil {
		return true, nil
	}
	if errors.Is(err, os.ErrNotExist) {
		return false, nil
	}
	return false, err
}

func resolveHomeDir(homeDir string) (string, error) {
	if homeDir != "" {
		return filepath.Abs(homeDir)
	}

	return os.UserHomeDir()
}
