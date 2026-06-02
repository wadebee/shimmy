SHIMMY_SUPPORTED_SHIMS='aws go gcloud jq netcat nmap opnsense-mcp-server rg task terraform textual gdrive'
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
