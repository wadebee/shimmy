# Image verification

`images.sh` owns catalog-driven concrete-version selection, validated image
reference enumeration, remote-inspection caching, and jq-backed index parsing
for the opt-in `shimmy images verify` command. It does not read credentials or
select a profile; callers provide the validated manifest context and the
catalog-default Skopeo and jq runtime paths.

## Parent context

- [shared library](../CONTEXT.md)
