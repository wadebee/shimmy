package main

import (
	"context"
	"fmt"
	"os"

	"github.com/wadebee/shimmy/samples/host/internal/hostcli"
)

func main() {
	if err := hostcli.Execute(context.Background(), os.Args[1:], hostcli.Options{
		WorkingDir: ".",
		Stdout:     os.Stdout,
		Stderr:     os.Stderr,
	}); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
