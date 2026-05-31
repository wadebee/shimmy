# Investigate how to fix these:
The container downloads the YAML module on each run because its module cache is ephemeral in this shim setup, so the test command is taking a little longer than a local Go install would.

There’s no host gofmt binary on PATH
    go: downloading gopkg.in/yaml.v3 v3.0.1
    internal/hostcli/cli_test.go

The bundled skill validator could not run because PyYAML is missing in this environment: ModuleNotFoundError: No module named 'yaml'

# -----------
note: the installer still reported an update to /Users/wade/.zshrc even with --no-startup, which is worth treating as a separate installer behavior issue if you want that flag to be strictly non-mutating for startup files. That looks like a separate installer behavior issue worth fixing if --no-startup should mean “do not touch startup files.”

# -----------
Do you want to allow the aws Shimmy wrapper to run Podman outside the sandbox for this non-mutating smoke check?  
    aws --version 
    shimmy test