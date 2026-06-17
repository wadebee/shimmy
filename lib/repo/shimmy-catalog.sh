SHIMMY_SUPPORTED_SHIMS='aws go gcloud gdrive jq netcat nmap oc oc_4_18 oc_4_20 oc_4_22 opnsense-mcp-admin opnsense-mcp-read-only rg task terraform textual'
SHIMMY_DEFAULT_SHIMS='jq rg'

shimmy_default_shim_list() {
  printf '%s\n' "$SHIMMY_DEFAULT_SHIMS"
}

shimmy_is_supported_shim() {
  requested_shim=${1:?shim name is required}

  for supported_shim in $SHIMMY_SUPPORTED_SHIMS; do
    if [ "$supported_shim" = "$requested_shim" ]; then
      return 0
    fi
  done

  return 1
}

shimmy_supported_shim_list() {
  printf '%s\n' "$SHIMMY_SUPPORTED_SHIMS"
}
