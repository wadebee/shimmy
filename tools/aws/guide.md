# AWS CLI Shim

## Upstream

- Source repo README: <https://github.com/aws/aws-cli/blob/v2/README.rst>
- Latest release/version source: <https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst>
- Official docs: <https://docs.aws.amazon.com/cli/>
- Shim image: `public.ecr.aws/aws-cli/aws-cli@sha256:40033dc921634b1073094712ea8237869bc857cd7ddc2571896ec9b14ef97ae8` from `versions/2.31/image.conf`

## Upstream README Summary

AWS CLI is Amazon's unified command-line interface for AWS services. The upstream project focuses on installing and running the CLI, configuring credentials and regions, and using service-specific commands that map to AWS APIs.

## Top-Level Command Summary

AWS CLI commands are primarily service namespaces. Common examples:

- `aws configure` - write local credentials and default region settings.
- `aws sts` - inspect caller identity and session information.
- `aws s3` - high-level S3 bucket and object operations.
- `aws ec2` - manage EC2 instances, networking, and related resources.
- `aws iam` - inspect and manage IAM users, roles, policies, and access keys.
- `aws cloudformation` - deploy and inspect CloudFormation stacks.

## Shimmy Usage

```sh
aws --version
aws sts get-caller-identity
aws s3 ls
```

Environment:

- `SHIMMY_AWS_IMAGE` - override the container image.
- `SHIMMY_AWS_IMAGE_PULL=always` - force pulling the configured image.
- `SHIMMY_HOST_CA_BUNDLE=/absolute/path/to/bundle.pem` - mount one host CA
  bundle read-only and map it to the AWS CLI's `AWS_CA_BUNDLE` setting.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.aws` -> `/root/.aws` read-only when it exists.
- `SHIMMY_HOST_CA_BUNDLE` -> `/tmp/shimmy-host-ca-bundle.pem` read-only when
  configured.

Forwarded environment:

- `AWS_*`

Host CA trust:

- `SHIMMY_HOST_CA_BUNDLE` is interpreted only by the host wrapper; it is not
  forwarded into the container. The AWS CLI receives
  `AWS_CA_BUNDLE=/tmp/shimmy-host-ca-bundle.pem` explicitly after broad
  `AWS_*` forwarding.
- `AWS_CA_BUNDLE` is a custom, replacement-capable CA mechanism. If public AWS
  endpoints and a private corporate CA must both remain trusted, provide a
  combined bundle containing the required public and private roots. Shimmy
  mounts the supplied file as-is and does not parse or merge certificates.

Runtime platform:

- Linux or macOS on `amd64` -> `linux/amd64`
- Linux or macOS on `arm64` -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `aws` to list my S3 backup bucket and show me the exact command to sync a local `photos/` folder without deleting remote files."
- Software dev: "Use `aws sts get-caller-identity` and then show the AWS account, ARN, and region I am currently targeting."
- Platform engineer: "Use `aws cloudformation describe-stacks` to summarize failed stack events for the current environment."
