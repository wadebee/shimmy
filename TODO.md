# Investigate how to fix these:
The container downloads the YAML module on each run because its module cache is ephemeral in this shim setup, so the test command is taking a little longer than a local Go install would.

There’s no host gofmt binary on PATH
    go: downloading gopkg.in/yaml.v3 v3.0.1
    internal/hostcli/cli_test.go

The bundled skill validator could not run because PyYAML is missing in this environment: ModuleNotFoundError: No module named 'yaml'