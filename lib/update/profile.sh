#!/bin/sh
# Profile-local update helpers.

shimmy_update_profile_validate() {
  shimmy_profile_context_resolve "$ROOT_DIR" || fail "update must run from a canonical installed profile"
  shimmy_profile_structure_validate "$SHIMMY_PROFILE_ROOT" "$SHIMMY_PROFILE_NAME" || fail "incomplete or damaged Shimmy profile at $SHIMMY_PROFILE_ROOT"
  if [ "$SHIMMY_PROFILE_NAME" = upstream ]; then
    source_checkout=$(shimmy_read_manifest_value "$SHIMMY_PROFILE_MANIFEST_PATH" source_checkout || true)
    upstream_invalid_reason=$(shimmy_upstream_checkout_invalid_reason "$source_checkout" || true)
    [ -z "$upstream_invalid_reason" ] || fail "invalid upstream source checkout ($upstream_invalid_reason): $source_checkout"
  fi
}
