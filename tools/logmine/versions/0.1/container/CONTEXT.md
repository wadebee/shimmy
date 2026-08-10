# Logmine 0.1 container build context

This directory contains the local build context and Containerfile used by the
Logmine shim. The required Go base argument is always supplied from validated
image configuration or its runtime override.
The source default is an immutable audited commit; upstream currently publishes
no version tags. Its committed `go.sum` omits the content checksum for the
declared `golang.org/x/sys` transitive version, so the build refreshes the
module data from the already-pinned `github.com/sirupsen/logrus@v1.6.0`
requirement before compiling the root command rather than resolving an
unpinned replacement or treating library subpackages as separate binaries.
