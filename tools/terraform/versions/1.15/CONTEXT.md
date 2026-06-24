# Terraform 1.15 runtime

`run.sh` is the concrete remote-image runtime for Terraform commands.
`refresh.sh` pulls its effective image for `shimmy update --pull` using
`smoke.conf`.
