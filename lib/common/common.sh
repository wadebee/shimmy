# Shared path, manifest, and list helpers.
shimmy_append_line_list() {
  list_value=${1:-}
  line_value=$2

  if [ -n "$list_value" ]; then
    printf '%s\n%s\n' "$list_value" "$line_value"
  else
    printf '%s\n' "$line_value"
  fi
}

shimmy_contains_line_list() {
  list_value=${1:-}
  line_value=$2

  while IFS= read -r existing_line; do
    [ -n "$existing_line" ] || continue
    if [ "$existing_line" = "$line_value" ]; then
      return 0
    fi
  done <<EOF
$list_value
EOF

  return 1
}

shimmy_join_path() {
  base_path=$1
  path_suffix=$2
  base_path=$(shimmy_trim_path_trailing_slash "$base_path")
  if [ "$base_path" = / ]; then
    printf '/%s\n' "$path_suffix"
  else
    printf '%s/%s\n' "$base_path" "$path_suffix"
  fi
}

shimmy_quote_shell_word() {
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

shimmy_resolve_path_absolute() {
  path_value=${1:-}

  if [ -z "$path_value" ]; then
    return 1
  fi

  path_value=$(shimmy_trim_path_trailing_slash "$path_value")

  if [ -d "$path_value" ]; then
    (
      cd -- "$path_value" && pwd -P
    )
    return 0
  fi

  path_dir=$(dirname "$path_value")
  path_base=$(basename "$path_value")

  if [ -d "$path_dir" ]; then
    (
      cd -- "$path_dir" && printf '%s/%s\n' "$(pwd -P)" "$path_base"
    )
    return 0
  fi

  case "$path_value" in
    /*)
      printf '%s\n' "$path_value"
      ;;
    *)
      printf '%s/%s\n' "$(pwd -P)" "$path_value"
      ;;
  esac
}

shimmy_trim_path_trailing_slash() {
  path_value=${1:-}

  while [ "$path_value" != / ]; do
    case "$path_value" in
      */) path_value=${path_value%/} ;;
      *) break ;;
    esac
  done
  printf '%s\n' "$path_value"
}

shimmy_validate_remove_path_safe() {
  path_value=$1

  case "$path_value" in
    ''|/)
      return 1
      ;;
  esac

  return 0
}

shimmy_path_parent_chain_validate() {
  path_value=$1

  case "$path_value" in
    /*) ;;
    *) return 1 ;;
  esac

  while [ "$path_value" != / ]; do
    [ ! -L "$path_value" ] || return 1
    path_value=$(dirname -- "$path_value")
  done
}

# State token and codec helpers.
shimmy_name_component_validate() {
  case "${1:-}" in
    ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_version_token_validate() {
  case "${1:-}" in
    ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_git_commit_validate() {
  shimmy_git_commit_value=${1:-}
  case "${#shimmy_git_commit_value}" in 40|64) ;; *) return 1 ;; esac
  case "$shimmy_git_commit_value" in *[!0123456789abcdef]*) return 1 ;; esac
}

shimmy_sha256_fingerprint_validate() {
  shimmy_sha256_fingerprint_value=${1:-}
  case "$shimmy_sha256_fingerprint_value" in sha256:*) ;;
    *) return 1 ;;
  esac
  shimmy_sha256_fingerprint_hex=${shimmy_sha256_fingerprint_value#sha256:}
  [ "${#shimmy_sha256_fingerprint_hex}" -eq 64 ] || return 1
  case "$shimmy_sha256_fingerprint_hex" in *[!0123456789abcdef]*) return 1 ;; esac
}

shimmy_sha256_file_render() {
  shimmy_sha256_file=$1
  [ -f "$shimmy_sha256_file" ] && [ ! -L "$shimmy_sha256_file" ] || return 1

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$shimmy_sha256_file" | awk '{ print $1 }'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$shimmy_sha256_file" | awk '{ print $1 }'
    return 0
  fi
  return 1
}

shimmy_sha256_fingerprint_file_render() {
  shimmy_sha256_fingerprint_file_hash=$(shimmy_sha256_file_render "$1") || return 1
  printf 'sha256:%s\n' "$shimmy_sha256_fingerprint_file_hash"
}

shimmy_text_file_validate() {
  shimmy_text_file=$1
  [ -f "$shimmy_text_file" ] && [ ! -L "$shimmy_text_file" ] || return 1
  [ -s "$shimmy_text_file" ] || return 1
  shimmy_text_file_final_byte=$(tail -c 1 "$shimmy_text_file" | od -An -tu1 | tr -d ' ')
  [ "$shimmy_text_file_final_byte" = 10 ] || return 1
  LC_ALL=C tr -d '\000' < "$shimmy_text_file" | cmp -s - "$shimmy_text_file"
}

shimmy_record_component_validate() {
  shimmy_record_component_value=${1:-}
  [ -n "$shimmy_record_component_value" ] || return 1
  case "$shimmy_record_component_value" in
    *'|'*) return 1 ;;
  esac
  shimmy_scalar_value_validate "$shimmy_record_component_value"
}

shimmy_scalar_value_validate() {
  shimmy_scalar_value=${1:-}
  shimmy_scalar_carriage_return=$(printf '\r')
  case "$shimmy_scalar_value" in
    *"
"*|*"$shimmy_scalar_carriage_return"*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_path_absolute_normalized_validate() {
  shimmy_path_normalized_value=${1:-}
  shimmy_scalar_value_validate "$shimmy_path_normalized_value" || return 1
  case "$shimmy_path_normalized_value" in
    /|''|/*/|*//*|*/./*|*/../*|*/.|*/..) return 1 ;;
    /*) ;;
    *) return 1 ;;
  esac
}

shimmy_shell_function_name_validate() {
  case "${1:-}" in
    ''|[!abcdefghijklmnopqrstuvwxyz_]*|*[!abcdefghijklmnopqrstuvwxyz0123456789_]*) return 1 ;;
    *) return 0 ;;
  esac
}

shimmy_line_list_lexical_unique_validate() {
  shimmy_line_list_value=${1:-}
  [ -z "$shimmy_line_list_value" ] && return 0
  shimmy_line_list_sorted=$(printf '%s\n' "$shimmy_line_list_value" | LC_ALL=C sort -u) || return 1
  [ "$shimmy_line_list_value" = "$shimmy_line_list_sorted" ]
}

# Encode arbitrary public manifest fields without interpreting their contents.
# A sentinel preserves embedded and trailing newlines while awk processes the
# value as line records.
shimmy_manifest_value_encode() {
  shimmy_manifest_encode_value=${1-}
  printf '%sX' "$shimmy_manifest_encode_value" | awk -v cr="$(printf '\r')" '
    function encode(line) {
      gsub(/%/, "%25", line)
      gsub(/\|/, "%7C", line)
      gsub(cr, "%0D", line)
      return line
    }
    NR > 1 { printf "%s%%0A", encode(previous) }
    { previous = $0 }
    END {
      final = previous
      final = substr(final, 1, length(final) - 1)
      printf "%s", encode(final)
    }
  '
}

shimmy_manifest_value_decode() {
  shimmy_manifest_decode_value=${1-}
  printf '%s' "$shimmy_manifest_decode_value" | awk '
    BEGIN { ORS = "" }
    {
      if (NR > 1) value = value "\n"
      value = value $0
    }
    END {
      for (position = 1; position <= length(value); position++) {
        token = substr(value, position, 3)
        if (token == "%0A") { printf "\n"; position += 2 }
        else if (token == "%0D") { printf "\r"; position += 2 }
        else if (token == "%7C") { printf "|"; position += 2 }
        else if (token == "%25") { printf "%%"; position += 2 }
        else printf "%s", substr(value, position, 1)
      }
    }
  '
}

shimmy_manifest_diagnostic_encode() {
  shimmy_manifest_diagnostic_encoded=$(shimmy_manifest_value_encode "${1-}") || return 1
  shift
  for shimmy_manifest_diagnostic_secret do
    [ -n "$shimmy_manifest_diagnostic_secret" ] || continue
    shimmy_manifest_diagnostic_needle=$(shimmy_manifest_value_encode "$shimmy_manifest_diagnostic_secret") || return 1
    shimmy_manifest_diagnostic_encoded=$(
      printf '%s' "$shimmy_manifest_diagnostic_encoded" | \
        SHIMMY_MANIFEST_REDACT_NEEDLE="$shimmy_manifest_diagnostic_needle" awk '
        BEGIN { ORS = ""; needle = ENVIRON["SHIMMY_MANIFEST_REDACT_NEEDLE"] }
        { value = value $0 }
        END {
          while (length(value) > 0) {
            position = index(value, needle)
            if (position == 0) { printf "%s", value; break }
            printf "%s[redacted]", substr(value, 1, position - 1)
            value = substr(value, position + length(needle))
          }
        }
      '
    ) || return 1
  done
  printf '%s' "$shimmy_manifest_diagnostic_encoded"
}

# TUI Style, color, and formatting helpers.
shimmy_style_init() {
  if [ -t 1 ]; then
    shimmy_style_esc=$(printf '\033')
    SHIMMY_STYLE_BOLD="${shimmy_style_esc}[1m"
    SHIMMY_STYLE_DIM="${shimmy_style_esc}[2m"
    SHIMMY_STYLE_GREEN="${shimmy_style_esc}[32m"
    SHIMMY_STYLE_RED="${shimmy_style_esc}[31m"
    SHIMMY_STYLE_YELLOW="${shimmy_style_esc}[33m"
    SHIMMY_STYLE_CYAN="${shimmy_style_esc}[36m"
    SHIMMY_STYLE_RESET="${shimmy_style_esc}[0m"
  else
    SHIMMY_STYLE_BOLD=''
    SHIMMY_STYLE_DIM=''
    SHIMMY_STYLE_GREEN=''
    SHIMMY_STYLE_RED=''
    SHIMMY_STYLE_YELLOW=''
    SHIMMY_STYLE_CYAN=''
    SHIMMY_STYLE_RESET=''
  fi
}

shimmy_digest_format() {
  shimmy_digest_val=${1:-}
  if [ -z "$shimmy_digest_val" ] || [ "$shimmy_digest_val" = - ]; then
    printf -- '-\n'
    return
  fi
  case "$shimmy_digest_val" in
    sha256:*|sha256-*)
      shimmy_digest_hex=${shimmy_digest_val#sha256:}
      shimmy_digest_hex=${shimmy_digest_hex#sha256-}
      printf 'sha256:%.12s\n' "$shimmy_digest_hex"
      ;;
    *)
      printf '%.12s\n' "$shimmy_digest_val"
      ;;
  esac
}

shimmy_draw_line() {
  shimmy_line_length=$1
  shimmy_line_char=${2:-─}
  shimmy_line_str=""
  while [ "${#shimmy_line_str}" -lt "$shimmy_line_length" ]; do
    shimmy_line_str="${shimmy_line_str}${shimmy_line_char}"
  done
  printf '%s' "$shimmy_line_str"
}

shimmy_section_header() {
  shimmy_sec_title=$1
  shimmy_style_init
  shimmy_sec_len=${#shimmy_sec_title}
  shimmy_sec_pad=$((75 - shimmy_sec_len - 6))
  if [ "$shimmy_sec_pad" -lt 0 ]; then
    shimmy_sec_pad=0
  fi
  printf '%s─── %s %s%s\n' "$SHIMMY_STYLE_BOLD" "$shimmy_sec_title" "$(shimmy_draw_line "$shimmy_sec_pad")" "$SHIMMY_STYLE_RESET"
}
