# Image verification

`images.sh` owns catalog-driven concrete-version selection, validated image
reference enumeration, remote-inspection caching, and jq-backed index parsing
for the opt-in `shimmy images verify` command. It does not read credentials or
select a profile; callers first resolve and validate the profile's named
catalog. Catalog-wide and explicit request selection use catalog metadata;
the installed default selection uses manifest-recorded versions and their
profile-materialized image metadata. Installed invocations execute the
invoking profile's materialized Skopeo and jq runtimes. Source invocations
execute the checkout materialization.

`target.sh` is the private target-catalog verifier. It validates the target
catalog and active version-2 profile, verifies the current immutable catalog
generation, and resolves jq/Skopeo only from exact default-version records and
regular executable files in that active profile's materialization. Missing
dependencies report exact versioned `shim add` remediation. It preserves the
current index, platform, authentication, cache, drift, and `image_verify`
semantics without adding a public route.

## Parent context

- [shared library](../CONTEXT.md)
