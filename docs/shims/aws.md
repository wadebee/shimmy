# AWS CLI Shim

## Upstream

- Source repo README: <https://github.com/aws/aws-cli/blob/v2/README.rst>
- Latest release/version source: <https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst>
- Official docs: <https://docs.aws.amazon.com/cli/>
- Shim image: `public.ecr.aws/aws-cli/aws-cli:2.31.21`

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

- `AWS_IMAGE` - override the container image.
- `AWS_IMAGE_PULL=always` - force pulling the configured image.

Mounts:

- `$PWD` -> `/work` read-write.
- `~/.aws` -> `/root/.aws` read-only when it exists.

Forwarded environment:

- `AWS_*`

Runtime platform:

- Linux -> `linux/amd64`
- macOS -> `linux/arm64`

## Quick-Start Prompts

- Home labber: "Use `aws` to list my S3 backup bucket and show me the exact command to sync a local `photos/` folder without deleting remote files."
- Software dev: "Use `aws sts get-caller-identity` and then show the AWS account, ARN, and region I am currently targeting."
- Platform engineer: "Use `aws cloudformation describe-stacks` to summarize failed stack events for the current environment."
