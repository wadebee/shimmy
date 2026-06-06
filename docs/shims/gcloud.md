# Google Cloud CLI Shim

## Upstream

- Source repo README: <https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/main/README.md>
- Latest release: <https://github.com/GoogleCloudPlatform/cloud-sdk-docker/releases>
- Docs: <https://cloud.google.com/sdk/docs>
- Shim image: `gcr.io/google.com/cloudsdktool/google-cloud-cli:stable`
- Image docs: <https://cloud.google.com/sdk/docs/downloads-docker>

## Upstream README Summary

Google Cloud CLI (gcloud) is the primary command-line interface for Google Cloud Platform services. It enables users to manage resources, authenticate, and interact with GCP services like Compute Engine, Kubernetes Engine, Cloud Storage, and more.

## Top-Level Command Summary

- `gcloud init` - initialize the gcloud environment and set up authentication.
- `gcloud auth login` - obtain user credentials via OAuth 2.0.
- `gcloud auth application-default login` - obtain application default credentials.
- `gcloud projects list` - list accessible Google Cloud projects.
- `gcloud config set project PROJECT_ID` - set the default project.
- `gcloud compute instances list` - list Compute Engine VM instances.
- `gcloud container clusters list` - list GKE clusters.
- `gcloud storage ls` - list Cloud Storage buckets.
- `gcloud app deploy` - deploy an application to App Engine.
- `gcloud functions deploy` - deploy a function to Cloud Functions.
- `gcloud run deploy` - deploy a service to Cloud Run.

## Shimmy Usage

```sh
gcloud --shimmy-config-help
gcloud version
gcloud auth list
gcloud projects list
```

Environment:

- `SHIMMY_GCLOUD_IMAGE` - override the container image.
- `SHIMMY_GCLOUD_IMAGE_PULL=always` - force pulling the configured image.
- `CLOUDSDK_CONFIG` - standard Google Cloud CLI config directory override. When set on the host, Shimmy creates and mounts that directory instead of `$HOME/.config/gcloud`.

The default image uses Google's documented Google Cloud CLI image repository and the `:stable` tag because it supports both `linux/amd64` and `linux/arm64` platforms.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.config/gcloud` or host `CLOUDSDK_CONFIG` -> `/home/cloudsdk/.config/gcloud` read-write. Shimmy creates the host directory when needed.
- `~/.kube/config` -> `/home/cloudsdk/.kube/config` read-only when it exists.

Container user and config:

- The container runs as the image's built-in `cloudsdk` user.
- Shimmy sets container `HOME=/home/cloudsdk`.
- Shimmy uses host `CLOUDSDK_CONFIG` as the source directory when it is set, then sets container `CLOUDSDK_CONFIG=/home/cloudsdk/.config/gcloud` so the mounted config directory is used consistently.

Configuration diagnostics:

- `gcloud --shimmy-config-help` prints the host `HOME`, host `CLOUDSDK_CONFIG`, the expected `~/.config/gcloud` and `~/.kube/config` paths, the effective host config directory, whether those paths exist, and the current mount policy.
- Shimmy creates host `CLOUDSDK_CONFIG` when set, otherwise host `~/.config/gcloud` when `HOME` is set, during normal gcloud execution. The diagnostic command does not create it.
- Shimmy does not create credentials or Google Cloud CLI configuration files automatically.
- If the mounted config directory is empty or unconfigured, auth-dependent read commands such as `gcloud auth list` or `gcloud projects list` may fail with upstream Google Cloud CLI auth/config errors.
- Config-writing commands such as `gcloud init`, `gcloud auth login`, `gcloud auth application-default login`, and `gcloud config set` run through the shim and can write to the mounted config directory.

Forwarded environment:

- `CLOUDSDK_*`

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `gcloud compute instances list` to show my VM instances in the default project and zone."
- Software dev: "Use `gcloud auth list` to see which accounts are authenticated, then run `gcloud config list` to view the current configuration."
- Platform engineer: "Use `gcloud container clusters list` to summarize all GKE clusters across projects, then show nodes for a specific cluster."
