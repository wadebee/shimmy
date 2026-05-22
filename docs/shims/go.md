# Go Shim

## Upstream

- Source repo README: <https://github.com/golang/go/blob/master/README.md>
- Latest release downloads: <https://go.dev/dl/>
- Release notes: <https://go.dev/doc/devel/release>
- Shim image: `docker.io/library/golang:latest`

## Upstream README Summary

Go is an open-source programming language and toolchain. The upstream repository README explains how to build Go from source, where to find documentation, and how development of the compiler, standard library, and tooling is organized.

## Top-Level Command Summary

- `go build` - compile packages and commands.
- `go test` - run tests and benchmarks.
- `go run` - compile and run a package.
- `go mod` - manage modules and dependencies.
- `go env` - print Go environment settings.
- `go fmt` - format Go source files.
- `go vet` - report suspicious code patterns.
- `go install` - compile and install commands.

## Shimmy Usage

```sh
go version
go test ./...
go env GOARCH
```

Environment:

- `GO_IMAGE` - override the container image.
- `GO_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.

Container I/O:

- The shim keeps stdin open without allocating a TTY, which keeps short commands such as `go help test` clean in scripts.

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `go test ./...` to verify this small home automation service before I deploy it."
- Software dev: "Run the Go test suite and summarize failing packages with the exact test names."
- Platform engineer: "Use `go env` to confirm the target architecture and module cache settings for this build container."
