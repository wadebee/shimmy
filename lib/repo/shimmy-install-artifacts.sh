#!/usr/bin/env bash

shimmy::dir_parent_empty_remove() {
  local dir="${1:?dir path is required}"
  local stop_dir="${2:?stop dir is required}"

  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if rmdir "$dir" 2>/dev/null; then
      shimmy::log_debug "Removed empty directory: $dir"
    else
      shimmy::log_debug "Stopped removing parent directories at non-empty or inaccessible path: $dir"
      break
    fi
    if [[ "$dir" == "$stop_dir" ]]; then
      shimmy::log_debug "Reached directory cleanup boundary: $stop_dir"
      break
    fi
    dir="$(dirname "$dir")"
  done
}

shimmy::file_delete_if_empty() {
  local file="${1:?file path is required}"

  if [[ ! -f "$file" ]]; then
    shimmy::log_debug "Skipping empty-file cleanup; file not found: $file"
    return 0
  fi
  if ! grep -q '[^[:space:]]' "$file"; then
    shimmy::log_debug "Removing empty file: $file"
    rm -f "$file"
  else
    shimmy::log_debug "Keeping non-empty file: $file"
  fi
}

shimmy::install_manifest_profile_files_delete() {
  local manifest_file="${1:?manifest file is required}"
  local install_dir="${2:?install dir is required}"
  local line
  local path

  if [[ ! -f "$manifest_file" ]]; then
    shimmy::log_debug "No install manifest found; skipping managed profile file removal"
    return 0
  fi

  shimmy::log_debug "Removing profile files listed in manifest $manifest_file"
  while IFS= read -r line; do
    case "$line" in
      created_profile_file=*)
        path="${line#created_profile_file=}"
        shimmy::log_debug "Removing manifest-managed profile file: $path"
        rm -f "$path"
        shimmy::dir_parent_empty_remove "$(dirname "$path")" "$install_dir"
        ;;
      *)
        shimmy::log_debug "Ignoring manifest entry during profile cleanup: $line"
        ;;
    esac
  done < "$manifest_file"
}

shimmy::manifest_entries_write_from_array() {
  local manifest_key="${1:?manifest key is required}"
  local array_name="${2:?array name is required}"
  local item_count
  local item

  if [[ ! "$array_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    printf 'shimmy: invalid array name for manifest write: %s\n' "$array_name" >&2
    return 1
  fi

  eval 'item_count=${#'"$array_name"'[@]}'
  if [[ "$item_count" -eq 0 ]]; then
    return 0
  fi

  eval '
    for item in "${'"$array_name"'[@]}"; do
      printf '"'"'%s=%s\n'"'"' "$manifest_key" "$item"
    done
  '
}

shimmy::install_manifest_write() {
  local manifest_file="${1:?manifest file is required}"
  local install_dir="${2:?install dir is required}"
  local shim_dir="${3:?shim dir is required}"
  local images_dir="${4:?images dir is required}"
  local shim_lib_dir="${5:?shim lib dir is required}"
  local install_mode="${6:?install mode is required}"
  local update_bashrc="${7:?update bashrc flag is required}"
  local bashrc_file="${8:?bashrc file is required}"
  local bash_profile_file="${9:?bash profile file is required}"
  local bash_shimmy_file="${10:?bash shimmy file is required}"
  local requested_shims_name="${11:?requested shims name is required}"
  local created_shell_files_name="${12:?created shell files name is required}"

  shimmy::log_debug "Writing install manifest to $manifest_file"
  mkdir -p "$install_dir"

  {
    printf 'install_dir=%s\n' "$install_dir"
    printf 'shim_dir=%s\n' "$shim_dir"
    printf 'images_dir=%s\n' "$images_dir"
    printf 'shim_lib_dir=%s\n' "$shim_lib_dir"
    printf 'install_mode=%s\n' "$install_mode"
    printf 'update_bashrc=%s\n' "$update_bashrc"
    printf 'bashrc_file=%s\n' "$bashrc_file"
    printf 'bash_profile_file=%s\n' "$bash_profile_file"
    printf 'bash_shimmy_file=%s\n' "$bash_shimmy_file"
    shimmy::manifest_entries_write_from_array 'requested_shim' "$requested_shims_name"
    shimmy::manifest_entries_write_from_array 'created_shell_file' "$created_shell_files_name"
  } > "$manifest_file"
}

shimmy::is_install_manifest_path_listed() {
  local manifest_file="${1:?manifest file is required}"
  local key="${2:?manifest key is required}"
  local path="${3:?path is required}"

  if [[ ! -f "$manifest_file" ]]; then
    shimmy::log_debug "Manifest not found while checking $key for path $path"
    return 1
  fi

  if grep -Fx -- "$key=$path" "$manifest_file" >/dev/null; then
    shimmy::log_debug "Manifest contains $key entry for $path"
    return 0
  fi

  shimmy::log_debug "Manifest does not contain $key entry for $path"
  return 1
}

shimmy::is_path_within() {
  local parent="${1:?parent path is required}"
  local child="${2:?child path is required}"

  parent="${parent%/}"
  child="${child%/}"

  [[ "$child" == "$parent" || "$child" == "$parent"/* ]]
}

shimmy::managed_block_remove() {
  local file="${1:?file path is required}"
  local start_marker="${2:?start marker is required}"
  local end_marker="${3:?end marker is required}"
  local tmp

  if [[ ! -f "$file" ]]; then
    shimmy::log_debug "Skipping managed block removal; file not found: $file"
    return 0
  fi

  shimmy::log_debug "Removing managed block from $file using markers [$start_marker] and [$end_marker]"
  tmp="$(mktemp)"
  awk '
    BEGIN { skip=0 }
    $0 == start_marker { skip=1; next }
    $0 == end_marker { skip=0; next }
    skip { next }
    { print }
  ' start_marker="$start_marker" end_marker="$end_marker" "$file" > "$tmp"
  mv "$tmp" "$file"
}

shimmy::path_block_append() {
  local file="${1:?file path is required}"
  local shim_dir="${2:?shim dir is required}"
  local install_dir="${3:?install dir is required}"
  local images_dir="${4:?images dir is required}"
  local shim_lib_dir="${5:?shim lib dir is required}"

  shimmy::log_debug "Appending Shimmy PATH block to $file pointed at dir $shim_dir"
  shimmy::render_path_block \
    "$shim_dir" \
    "$install_dir" \
    "$images_dir" \
    "$shim_lib_dir" >> "$file"
}

shimmy::shell_init_block_append() {
  local file="${1:?file path is required}"
  local shimmy_bash_file="${2:?shimmy bash file is required}"

  shimmy::log_debug "Appending shell init block to $file"
  shimmy::render_shell_init_block "$shimmy_bash_file" >> "$file"
}
