SHIMMY_KINDS='aws go gcloud gdrive jq netcat nmap oc opnsense-mcp-admin opnsense-mcp-read-only rg task terraform tessl textual'
SHIMMY_DEFAULT_KINDS='jq rg'

shimmy_default_kind_list() {
  printf '%s\n' "$SHIMMY_DEFAULT_KINDS"
}

shimmy_is_kind() {
  kind_name=${1:?kind name is required}

  for catalog_kind in $SHIMMY_KINDS; do
    if [ "$catalog_kind" = "$kind_name" ]; then
      return 0
    fi
  done

  return 1
}

shimmy_is_version() {
  version_name=${1:?version name is required}

  if shimmy_version_kind "$version_name" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

shimmy_kind_default_version() {
  kind_name=${1:?kind name is required}

  case "$kind_name" in
    aws) printf '%s\n' aws_2_31 ;;
    go) printf '%s\n' go_1_26 ;;
    gcloud) printf '%s\n' gcloud_573_0 ;;
    gdrive) printf '%s\n' gdrive_0_2 ;;
    jq) printf '%s\n' jq_1_8 ;;
    netcat) printf '%s\n' netcat_7_92 ;;
    nmap) printf '%s\n' nmap_7_98 ;;
    oc) printf '%s\n' oc_4_20 ;;
    opnsense-mcp-admin) printf '%s\n' opnsense-mcp-admin_1_0 ;;
    opnsense-mcp-read-only) printf '%s\n' opnsense-mcp-read-only_0_4 ;;
    rg) printf '%s\n' rg_15_1 ;;
    task) printf '%s\n' task_3_45 ;;
    terraform) printf '%s\n' terraform_1_15 ;;
    tessl) printf '%s\n' tessl_0_1 ;;
    textual) printf '%s\n' textual_8_2 ;;
    *) return 1 ;;
  esac
}

shimmy_kind_list() {
  printf '%s\n' "$SHIMMY_KINDS"
}

shimmy_kind_selector_env() {
  kind_name=${1:?kind name is required}

  case "$kind_name" in
    oc) printf '%s\n' SHIMMY_OC_VERSION ;;
    *) return 0 ;;
  esac
}

shimmy_kind_version_for_label() {
  kind_name=${1:?kind name is required}
  version_label=${2:?version label is required}

  for version_name in $(shimmy_kind_version_list "$kind_name"); do
    if [ "$(shimmy_version_label "$version_name")" = "$version_label" ]; then
      printf '%s\n' "$version_name"
      return 0
    fi
  done

  return 1
}

shimmy_kind_version_label_list() {
  kind_name=${1:?kind name is required}

  for version_name in $(shimmy_kind_version_list "$kind_name"); do
    shimmy_version_label "$version_name"
  done
}

shimmy_kind_version_list() {
  kind_name=${1:?kind name is required}

  case "$kind_name" in
    aws) printf '%s\n' aws_2_31 ;;
    go) printf '%s\n' go_1_26 ;;
    gcloud) printf '%s\n' gcloud_573_0 ;;
    gdrive) printf '%s\n' gdrive_0_2 ;;
    jq) printf '%s\n' jq_1_8 ;;
    netcat) printf '%s\n' netcat_7_92 ;;
    nmap) printf '%s\n' nmap_7_98 ;;
    oc) printf '%s\n' 'oc_4_18 oc_4_20 oc_4_22' ;;
    opnsense-mcp-admin) printf '%s\n' opnsense-mcp-admin_1_0 ;;
    opnsense-mcp-read-only) printf '%s\n' opnsense-mcp-read-only_0_4 ;;
    rg) printf '%s\n' rg_15_1 ;;
    task) printf '%s\n' task_3_45 ;;
    terraform) printf '%s\n' terraform_1_15 ;;
    tessl) printf '%s\n' tessl_0_1 ;;
    textual) printf '%s\n' textual_8_2 ;;
    *) return 1 ;;
  esac
}

shimmy_version_kind() {
  version_name=${1:?version name is required}

  case "$version_name" in
    aws_2_31) printf '%s\n' aws ;;
    go_1_26) printf '%s\n' go ;;
    gcloud_573_0) printf '%s\n' gcloud ;;
    gdrive_0_2) printf '%s\n' gdrive ;;
    jq_1_8) printf '%s\n' jq ;;
    netcat_7_92) printf '%s\n' netcat ;;
    nmap_7_98) printf '%s\n' nmap ;;
    oc_4_18|oc_4_20|oc_4_22) printf '%s\n' oc ;;
    opnsense-mcp-admin_1_0) printf '%s\n' opnsense-mcp-admin ;;
    opnsense-mcp-read-only_0_4) printf '%s\n' opnsense-mcp-read-only ;;
    rg_15_1) printf '%s\n' rg ;;
    task_3_45) printf '%s\n' task ;;
    terraform_1_15) printf '%s\n' terraform ;;
    tessl_0_1) printf '%s\n' tessl ;;
    textual_8_2) printf '%s\n' textual ;;
    *) return 1 ;;
  esac
}

shimmy_version_label() {
  version_name=${1:?version name is required}

  case "$version_name" in
    aws_2_31) printf '%s\n' 2.31 ;;
    go_1_26) printf '%s\n' 1.26 ;;
    gcloud_573_0) printf '%s\n' 573.0 ;;
    gdrive_0_2) printf '%s\n' 0.2 ;;
    jq_1_8) printf '%s\n' 1.8 ;;
    netcat_7_92) printf '%s\n' 7.92 ;;
    nmap_7_98) printf '%s\n' 7.98 ;;
    oc_4_18) printf '%s\n' 4.18 ;;
    oc_4_20) printf '%s\n' 4.20 ;;
    oc_4_22) printf '%s\n' 4.22 ;;
    opnsense-mcp-admin_1_0) printf '%s\n' 1.0 ;;
    opnsense-mcp-read-only_0_4) printf '%s\n' 0.4 ;;
    rg_15_1) printf '%s\n' 15.1 ;;
    task_3_45) printf '%s\n' 3.45 ;;
    terraform_1_15) printf '%s\n' 1.15 ;;
    tessl_0_1) printf '%s\n' 0.1 ;;
    textual_8_2) printf '%s\n' 8.2 ;;
    *) return 1 ;;
  esac
}
