# Task image build

`Containerfile` receives the configured Alpine base through its required build
argument and installs the pinned target-aware Task release plus the Podman
remote client required by the documented host-integration workflow.
