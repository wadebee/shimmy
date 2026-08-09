# GitHub CLI image build

`Containerfile` receives the configured Alpine base through its required build
argument, downloads the pinned target-aware GitHub CLI release, and sets `gh`
as its entrypoint.
