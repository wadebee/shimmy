# Google Cloud CLI Shim

## Upstream

- Source repo README: <https://github.com/GoogleCloudPlatform/cloud-sdk-docker/blob/main/README.md>
- Latest release: <https://github.com/GoogleCloudPlatform/cloud-sdk-docker/releases>
- Docs: <https://cloud.google.com/sdk/docs>
- Shim image: `docker.io/google/cloud-sdk:latest`

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
gcloud version
gcloud auth list
gcloud projects list
```

Environment:

- `SHIMMY_GCLOUD_IMAGE` - override the container image.
- `SHIMMY_GCLOUD_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.config/gcloud` -> `/root/.config/gcloud` read-only when it exists.
- `~/.kube/config` -> `/root/.kube/config` read-only when it exists.

Forwarded environment:

- `CLOUDSDK_*`

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `gcloud compute instances list` to show my VM instances in the default project and zone."
- Software dev: "Use `gcloud auth list` to see which accounts are authenticated, then run `gcloud config list` to view the current configuration."
- Platform engineer: "Use `gcloud container clusters list` to summarize all GKE clusters across projects, then show nodes for a specific cluster."