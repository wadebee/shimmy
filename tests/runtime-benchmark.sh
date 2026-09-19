#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SAMPLE_COUNT=20
WARMUP_COUNT=3
OUTPUT_DIR=${OUTPUT_DIR:-}
REVIEW_ONLY=0
EXTENDED_ONLY=0
SESSION_COMMAND_COUNT=${SHIMMY_RUNTIME_BENCHMARK_SESSION_COMMAND_COUNT:-40}
SENSITIVITY_COMMAND_COUNT=${SHIMMY_RUNTIME_BENCHMARK_SENSITIVITY_COMMAND_COUNT:-200}

runtime_benchmark_usage() {
  cat <<'EOF'
Usage: ./tests/runtime-benchmark.sh [--samples <count>] [--warmups <count>] [--output <directory>] [--review-only|--extended-only]

Measures the selected installed profile's shell selection, activation dry run,
and rg/jq wrapper workloads. The benchmark creates only private JSON fixtures
and a transparent temporary Podman forwarding script. It does not activate a
profile, change a Podman connection, pull images, or build images.

--review-only measures the exact current preflight and dormant context,
affinity, and reachability review seams. It does not invoke a tool container.

--extended-only measures the installed full preflight, Darwin affinity,
individual Podman probes, direct equivalent containers, instrumented versus
uninstrumented wrappers, a benchmark-only minimum-association predicate, an
actual 40-rg/40-jq session, a 200-rg/200-jq sensitivity session, and bounded
container events. It does not activate a profile, change Podman connections or
registry policy, force image pulls, or change event configuration.
EOF
}

runtime_benchmark_positive_integer_require() {
  case "$1" in
    *[!0-9]*|'')
      printf 'ERROR: %s must be a positive integer.\n' "$2" >&2
      exit 2
      ;;
  esac
  [ "$1" -gt 0 ] || {
    printf 'ERROR: %s must be a positive integer.\n' "$2" >&2
    exit 2
  }
}

runtime_benchmark_options_parse() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --samples)
        [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: --samples requires a value.' >&2; exit 2; }
        SAMPLE_COUNT=$2
        shift 2
        ;;
      --warmups)
        [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: --warmups requires a value.' >&2; exit 2; }
        WARMUP_COUNT=$2
        shift 2
        ;;
      --output)
        [ "$#" -ge 2 ] || { printf '%s\n' 'ERROR: --output requires a directory.' >&2; exit 2; }
        OUTPUT_DIR=$2
        shift 2
        ;;
      --review-only)
        REVIEW_ONLY=1
        shift
        ;;
      --extended-only)
        EXTENDED_ONLY=1
        shift
        ;;
      -h|--help)
        runtime_benchmark_usage
        exit 0
        ;;
      *)
        printf 'ERROR: unknown argument: %s\n' "$1" >&2
        exit 2
        ;;
    esac
  done
  runtime_benchmark_positive_integer_require "$SAMPLE_COUNT" --samples
  runtime_benchmark_positive_integer_require "$WARMUP_COUNT" --warmups
  [ "$REVIEW_ONLY" -eq 0 ] || [ "$EXTENDED_ONLY" -eq 0 ] || {
    printf '%s\n' 'ERROR: --review-only and --extended-only are mutually exclusive.' >&2
    exit 2
  }
}

runtime_benchmark_value_read() {
  sed -n "s/^$2=//p" "$1" | sed -n '1p'
}

runtime_benchmark_active_profile_discover() {
  config_home=${XDG_CONFIG_HOME:-${HOME:?HOME is required}/.config}
  active_record=$config_home/shimmy/active-profile.conf
  [ -f "$active_record" ] && [ ! -L "$active_record" ] || {
    printf 'ERROR: active Shimmy profile record is unavailable: %s\n' "$active_record" >&2
    exit 1
  }
  ACTIVE_PROFILE=$(runtime_benchmark_value_read "$active_record" shimmy_active_profile_name)
  case "$ACTIVE_PROFILE" in
    ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)
      printf 'ERROR: active Shimmy profile name is invalid.\n' >&2
      exit 1
      ;;
  esac
  PROFILE_ROOT=$config_home/shimmy/profiles/$ACTIVE_PROFILE
  [ -d "$PROFILE_ROOT" ] && [ ! -L "$PROFILE_ROOT" ] || {
    printf 'ERROR: active Shimmy profile root is unavailable: %s\n' "$PROFILE_ROOT" >&2
    exit 1
  }
  PROFILE_LAUNCHER=$PROFILE_ROOT/bin/shimmy
  PROFILE_SHELL_INIT=$PROFILE_ROOT/shell-init.sh
  [ -x "$PROFILE_LAUNCHER" ] && [ -f "$PROFILE_SHELL_INIT" ] || {
    printf 'ERROR: active Shimmy profile launchers are unavailable.\n' >&2
    exit 1
  }

  PROFILE_ENGINE_BINDING=$PROFILE_ROOT/engine-binding.conf
  [ -f "$PROFILE_ENGINE_BINDING" ] && [ ! -L "$PROFILE_ENGINE_BINDING" ] || {
    printf 'ERROR: active Shimmy engine binding is unavailable: %s\n' "$PROFILE_ENGINE_BINDING" >&2
    exit 1
  }
  BINDING_ENGINE_ID=$(runtime_benchmark_value_read "$PROFILE_ENGINE_BINDING" engine)
  case "$BINDING_ENGINE_ID" in
    shared) ;;
    profile-*)
      binding_profile_name=${BINDING_ENGINE_ID#profile-}
      case "$binding_profile_name" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*) printf '%s\n' 'ERROR: active Shimmy engine identifier is invalid.' >&2; exit 1 ;; esac
      ;;
    *) printf '%s\n' 'ERROR: active Shimmy engine identifier is invalid.' >&2; exit 1 ;;
  esac
  ENGINE_RECORD=$config_home/shimmy/engines/$BINDING_ENGINE_ID/engine.conf
  [ -f "$ENGINE_RECORD" ] && [ ! -L "$ENGINE_RECORD" ] || {
    printf 'ERROR: active Shimmy engine record is unavailable: %s\n' "$ENGINE_RECORD" >&2
    exit 1
  }
  EXPECTED_CONNECTION=$(runtime_benchmark_value_read "$ENGINE_RECORD" connection)
  EXPECTED_MACHINE=$(runtime_benchmark_value_read "$ENGINE_RECORD" name)
  case "$EXPECTED_CONNECTION" in ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*) printf '%s\n' 'ERROR: expected Podman connection is invalid.' >&2; exit 1 ;; esac
  case "$EXPECTED_MACHINE" in ''|*[!abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-]*) printf '%s\n' 'ERROR: expected Podman machine is invalid.' >&2; exit 1 ;; esac

  RG_IMAGE_CONFIG=$PROFILE_ROOT/tools/rg/versions/15.1/image.conf
  JQ_IMAGE_CONFIG=$PROFILE_ROOT/tools/jq/versions/1.8/image.conf
  RG_IMAGE=$(runtime_benchmark_value_read "$RG_IMAGE_CONFIG" image_default_ref)
  JQ_IMAGE=$(runtime_benchmark_value_read "$JQ_IMAGE_CONFIG" image_default_ref)
  [ -n "$RG_IMAGE" ] && [ -n "$JQ_IMAGE" ] || {
    printf '%s\n' 'ERROR: installed rg/jq image references are unavailable.' >&2
    exit 1
  }
  case "$(uname -m)" in
    arm64|aarch64) BENCHMARK_PLATFORM=linux/arm64 ;;
    x86_64|amd64) BENCHMARK_PLATFORM=linux/amd64 ;;
    *) printf '%s\n' 'ERROR: unsupported benchmark host architecture.' >&2; exit 1 ;;
  esac
}

runtime_benchmark_output_prepare() {
  BASH_BIN=${SHIMMY_RUNTIME_BENCHMARK_BASH_BIN:-bash}
  command -v "$BASH_BIN" >/dev/null 2>&1 || {
    printf 'ERROR: bash is required for benchmark host elapsed measurements.\n' >&2
    exit 1
  }
  BASH_BIN=$(command -v "$BASH_BIN")
  export BASH_BIN

  if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/shimmy-runtime-benchmark.XXXXXX")
  else
    [ ! -e "$OUTPUT_DIR" ] && [ ! -L "$OUTPUT_DIR" ] || {
      printf 'ERROR: output path already exists: %s\n' "$OUTPUT_DIR" >&2
      exit 2
    }
    mkdir -p "$OUTPUT_DIR"
  fi
  OUTPUT_DIR=$(cd -- "$OUTPUT_DIR" && pwd -P)
  RAW_DIR=$OUTPUT_DIR/raw
  mkdir -p "$RAW_DIR" "$OUTPUT_DIR/bin" "$OUTPUT_DIR/fixtures"
}

runtime_benchmark_podman_proxy_create() {
  REAL_PODMAN=$(command -v podman 2>/dev/null || true)
  [ -n "$REAL_PODMAN" ] || {
    printf '%s\n' 'ERROR: podman must be available on PATH for runtime measurement.' >&2
    exit 1
  }
  case "$REAL_PODMAN" in /*) ;; *) REAL_PODMAN=$(cd -- "$(dirname -- "$REAL_PODMAN")" && pwd)/$(basename -- "$REAL_PODMAN") ;; esac
  export SHIMMY_RUNTIME_BENCHMARK_REAL_PODMAN=$REAL_PODMAN
  export SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG=$RAW_DIR/podman-calls.tsv
  cat > "$OUTPUT_DIR/bin/podman" <<'EOF'
#!/bin/sh
started=$(date +%s)
ordinal=$(wc -l < "$SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG" | tr -d ' ')
ordinal=$((ordinal + 1))
"$SHIMMY_RUNTIME_BENCHMARK_REAL_PODMAN" "$@"
status=$?
finished=$(date +%s)
printf '%s\t%s\t%s\t%s\t%s\n' "${SHIMMY_RUNTIME_BENCHMARK_LANE:-unknown}" "$ordinal" podman "$((finished - started))" "$status" >> "$SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG"
exit "$status"
EOF
  chmod 0700 "$OUTPUT_DIR/bin/podman"
  : > "$SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG"
}

runtime_benchmark_provenance_write() {
  if [ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]; then
    source_worktree_state=dirty
  else
    source_worktree_state=clean
  fi
  if [ "$REVIEW_ONLY" -eq 1 ]; then
    measurement_scope=review-only
  elif [ "$EXTENDED_ONLY" -eq 1 ]; then
    measurement_scope=extended-only
  else
    measurement_scope=workloads
  fi
  {
    printf 'source_commit=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
    printf 'source_worktree_state=%s\n' "$source_worktree_state"
    printf 'source_benchmark_blob=%s\n' "$(git -C "$ROOT_DIR" hash-object tests/runtime-benchmark.sh)"
    printf 'source_review_helper_blob=%s\n' "$(git -C "$ROOT_DIR" hash-object lib/runtime/preflight-review.sh)"
    printf 'installed_runtime_helper_blob=%s\n' "$(git -C "$ROOT_DIR" hash-object "$PROFILE_ROOT/lib/runtime/podman.sh")"
    printf 'installed_rg_runtime_blob=%s\n' "$(git -C "$ROOT_DIR" hash-object "$PROFILE_ROOT/tools/rg/versions/15.1/run.sh")"
    printf 'installed_jq_runtime_blob=%s\n' "$(git -C "$ROOT_DIR" hash-object "$PROFILE_ROOT/tools/jq/versions/1.8/run.sh")"
    printf 'measurement_scope=%s\n' "$measurement_scope"
    printf '%s\n' 'host_timer=bash-keyword-default'
    printf '%s\n' 'host_timer_resolution_seconds=0.001'
    printf 'active_profile=%s\n' "$ACTIVE_PROFILE"
    printf 'profile_root=%s\n' "$PROFILE_ROOT"
    printf 'host_os=%s\n' "$(uname -s)"
    printf 'host_arch=%s\n' "$(uname -m)"
    printf 'podman_bin=%s\n' "$REAL_PODMAN"
    printf 'podman_version=%s\n' "$("$REAL_PODMAN" version --format '{{.Client.Version}}' 2>/dev/null || printf unavailable)"
    printf 'profile_control_commit=%s\n' "$(runtime_benchmark_value_read "$PROFILE_ROOT/install-manifest.txt" shimmy_source_ref)"
    printf 'default_connection=%s\n' "$("$REAL_PODMAN" system connection list --format '{{range .}}{{if .Default}}{{.Name}}{{end}}{{end}}' 2>/dev/null || printf unavailable)"
    printf 'expected_connection=%s\n' "$EXPECTED_CONNECTION"
    printf 'expected_machine=%s\n' "$EXPECTED_MACHINE"
    printf 'binding_engine_id=%s\n' "$BINDING_ENGINE_ID"
    printf 'installed_rg_image=%s\n' "$RG_IMAGE"
    printf 'installed_jq_image=%s\n' "$JQ_IMAGE"
    if [ "$(uname -s)" = Linux ]; then
      printf 'rootless_socket=%s\n' "${XDG_RUNTIME_DIR:-unavailable}/podman/podman.sock"
      if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
        printf '%s\n' 'rootless_socket_present=true'
      else
        printf '%s\n' 'rootless_socket_present=false'
      fi
    else
      printf '%s\n' 'rootless_socket=not_applicable'
      printf '%s\n' 'rootless_socket_present=not_applicable'
    fi
  } > "$OUTPUT_DIR/provenance.conf"
}

runtime_benchmark_fixture_create() {
  fixture_index=1
  while [ "$fixture_index" -le 4 ]; do
    printf '{"record":"record-%s","value":%s}\n' "$fixture_index" "$fixture_index" > "$OUTPUT_DIR/fixtures/record-$fixture_index.json"
    fixture_index=$((fixture_index + 1))
  done
}

runtime_benchmark_elapsed_seconds_read() {
  awk '
    /^real[[:space:]]+/ {
      value = $2
      if (value ~ /^[0-9]+m[0-9]+([.][0-9]+)?s$/) {
        sub(/m/, " ", value)
        sub(/s$/, "", value)
        split(value, parts, " ")
        printf "%.9f\n", (parts[1] * 60) + parts[2]
        exit
      }
    }
  ' "$1"
}

runtime_benchmark_command_run() {
  lane=$1
  sample_file=$RAW_DIR/$lane.samples
  call_start=$(wc -l < "$SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG" | tr -d ' ')
  set +e
  SHIMMY_RUNTIME_BENCHMARK_LANE=$lane "$BASH_BIN" -c 'time "$@"' -- "$0" --internal-workload "$lane" > "$RAW_DIR/$lane.stdout" 2> "$RAW_DIR/$lane.time"
  status=$?
  set -e
  call_end=$(wc -l < "$SHIMMY_RUNTIME_BENCHMARK_PODMAN_LOG" | tr -d ' ')
  elapsed=$(runtime_benchmark_elapsed_seconds_read "$RAW_DIR/$lane.time")
  printf '%s\t%s\t%s\n' "${elapsed:-unavailable}" "$status" "$((call_end - call_start))" >> "$sample_file"
  return "$status"
}

runtime_benchmark_lane_measure() {
  lane=$1
  : > "$RAW_DIR/$lane.samples"
  sample_index=1
  while [ "$sample_index" -le "$WARMUP_COUNT" ]; do
    runtime_benchmark_command_run "$lane" >/dev/null 2>&1 || return $?
    sample_index=$((sample_index + 1))
  done
  : > "$RAW_DIR/$lane.samples"
  sample_index=1
  while [ "$sample_index" -le "$SAMPLE_COUNT" ]; do
    runtime_benchmark_command_run "$lane" || return $?
    sample_index=$((sample_index + 1))
  done
}

runtime_benchmark_lane_summary_write() {
  lane=$1
  sample_file=$RAW_DIR/$lane.samples
  awk -F '\t' -v lane="$lane" '
    $1 != "unavailable" { elapsed[++count] = $1; status[$2] += 1; calls += $3 }
    END {
      if (count == 0) { printf "lane=%s samples=0 status=unavailable\n", lane; exit }
      for (i = 1; i <= count; i++) for (j = i + 1; j <= count; j++) if (elapsed[i] > elapsed[j]) { value = elapsed[i]; elapsed[i] = elapsed[j]; elapsed[j] = value }
      median_index = int((count + 1) / 2)
      p95_index = int((count * 95 + 99) / 100)
      printf "lane=%s samples=%d median_seconds=%s p95_seconds=%s mean_podman_calls=%.2f", lane, count, elapsed[median_index], elapsed[p95_index], calls / count
      for (code in status) printf " status_%s=%d", code, status[code]
      printf "\n"
    }
  ' "$sample_file" >> "$OUTPUT_DIR/summary.txt"
}

runtime_benchmark_wrapper_run() {
  wrapper_name=$1
  shift
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  . "$PROFILE_SHELL_INIT"
  command "$wrapper_name" "$@"
}

runtime_benchmark_wrapper_uninstrumented_run() {
  wrapper_name=$1
  shift
  . "$PROFILE_SHELL_INIT"
  command "$wrapper_name" "$@"
}

runtime_benchmark_shell_selection_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  . "$PROFILE_SHELL_INIT"
}

runtime_benchmark_review_helpers_source() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  SHIMMY_RUNTIME_DIR=$PROFILE_ROOT/lib/runtime
  export SHIMMY_RUNTIME_DIR
  . "$ROOT_DIR/lib/runtime/podman.sh"
  . "$ROOT_DIR/lib/runtime/preflight-review.sh"
}

runtime_benchmark_preflight_current_run() {
  runtime_benchmark_review_helpers_source
  shimmy_podman_preflight_require "the runtime preflight review"
}

runtime_benchmark_preflight_context_review_run() {
  runtime_benchmark_review_helpers_source
  shimmy_podman_preflight_context_review_require "the runtime preflight review"
}

runtime_benchmark_profile_affinity_current_run() {
  runtime_benchmark_review_helpers_source
  shimmy_podman_profile_affinity_require
}

runtime_benchmark_preflight_reachability_review_run() {
  runtime_benchmark_review_helpers_source
  SHIMMY_PODMAN_BIN=$OUTPUT_DIR/bin/podman
  export SHIMMY_PODMAN_BIN
  shimmy_podman_preflight_reachability_review_require "the runtime preflight review"
}

runtime_benchmark_installed_helpers_source() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  SHIMMY_RUNTIME_DIR=$PROFILE_ROOT/lib/runtime
  export SHIMMY_RUNTIME_DIR
  . "$PROFILE_ROOT/lib/runtime/podman.sh"
}

runtime_benchmark_preflight_installed_run() {
  runtime_benchmark_installed_helpers_source
  shimmy_podman_preflight_require "the installed runtime preflight benchmark"
}

runtime_benchmark_affinity_installed_run() {
  runtime_benchmark_installed_helpers_source
  shimmy_podman_profile_affinity_require
}

runtime_benchmark_probe_machine_list_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman machine list --format '{{.Name}}|{{.Running}}' >/dev/null
}

runtime_benchmark_probe_connection_list_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman system connection list --format '{{.Name}}|{{.URI}}|{{.Default}}' >/dev/null
}

runtime_benchmark_probe_workload_ps_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman --connection "$EXPECTED_CONNECTION" ps --format '{{.ID}}|{{.Names}}' >/dev/null
}

runtime_benchmark_probe_info_unqualified_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}|{{.Host.Hostname}}|{{.Store.GraphRoot}}'
}

runtime_benchmark_probe_info_explicit_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman --connection "$EXPECTED_CONNECTION" info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}|{{.Host.Hostname}}|{{.Store.GraphRoot}}'
}

runtime_benchmark_direct_rg_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman run --rm -i --platform "$BENCHMARK_PLATFORM" -v "$PWD:/work" -w /work "$RG_IMAGE" --version
}

runtime_benchmark_direct_jq_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  podman run --rm -i --platform "$BENCHMARK_PLATFORM" -v "$PWD:/work" -w /work "$JQ_IMAGE" --version
}

runtime_benchmark_minimum_association_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  for association_helper in \
    "$PROFILE_ROOT/lib/common/common.sh" \
    "$PROFILE_ROOT/lib/catalog/state.sh" \
    "$PROFILE_ROOT/lib/shim/state.sh" \
    "$PROFILE_ROOT/lib/profile/profile.sh" \
    "$PROFILE_ROOT/lib/profile/state.sh" \
    "$PROFILE_ROOT/lib/profile/activation.sh" \
    "$PROFILE_ROOT/lib/registries/registries.sh" \
    "$PROFILE_ROOT/lib/engine/state.sh" \
    "$PROFILE_ROOT/lib/engine/podman.sh" \
    "$PROFILE_ROOT/lib/engine/projection.sh" \
    "$PROFILE_ROOT/lib/engine/registry.sh"
  do
    . "$association_helper"
  done

  shimmy_profile_paths_resolve_name "$ACTIVE_PROFILE"
  shimmy_profile_runtime_manifest_identity_validate "$SHIMMY_PROFILE_MANIFEST_PATH" "$ACTIVE_PROFILE"
  shimmy_profile_manifest_read "$SHIMMY_PROFILE_MANIFEST_PATH"
  [ "$SHIMMY_PROFILE_NAME" = "$ACTIVE_PROFILE" ]
  shimmy_active_profile_read "$SHIMMY_CONFIG_ROOT/active-profile.conf"
  [ "$SHIMMY_ACTIVE_PROFILE_NAME" = "$ACTIVE_PROFILE" ]
  shimmy_engine_profile_binding_resolve "$SHIMMY_CONFIG_ROOT" "$ACTIVE_PROFILE"
  [ "$SHIMMY_PROFILE_EXPECTED_MACHINE" = "$EXPECTED_MACHINE" ]
  [ "$SHIMMY_PROFILE_EXPECTED_CONNECTION" = "$EXPECTED_CONNECTION" ]
  [ "$SHIMMY_PROFILE_EXPECTED_MACHINE" = "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ]
  shimmy_profile_activation_override_read
  [ "$SHIMMY_PROFILE_CONNECTION_OVERRIDE" = none ]
  shimmy_registries_override_read
  [ "$SHIMMY_REGISTRIES_OVERRIDE" = none ]
  shimmy_registries_config_validate "$SHIMMY_PROFILE_REGISTRIES_PATH" "$ACTIVE_PROFILE"
  shimmy_engine_registry_projection_state_read "$SHIMMY_CONFIG_ROOT" "$ACTIVE_PROFILE" "$SHIMMY_PROFILE_ENGINE_ID"
  [ "$SHIMMY_ENGINE_REGISTRY_PROJECTION_STATE" = current ]
  shimmy_engine_podman_bin_require
  shimmy_engine_podman_machine_state_read "$SHIMMY_PROFILE_EXPECTED_MACHINE"
  [ "$SHIMMY_ENGINE_MACHINE_STATE" = running ]
  shimmy_engine_podman_connection_state_read "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
  [ "$SHIMMY_ENGINE_CONNECTION_STATE" = rootless ]
  [ "$SHIMMY_ENGINE_DEFAULT_CONNECTION" = "$SHIMMY_PROFILE_EXPECTED_CONNECTION" ]
  association_info=$(shimmy_engine_podman_connection_run "$SHIMMY_PROFILE_EXPECTED_CONNECTION" \
    info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}')
  [ "$association_info" = 'true|true' ]
  printf 'active_profile=%s binding=%s connection=%s overrides=none registry_projection=current machine=running target=rootless-remote\n' \
    "$ACTIVE_PROFILE" "$SHIMMY_PROFILE_ENGINE_ID" "$SHIMMY_PROFILE_EXPECTED_CONNECTION"
}

runtime_benchmark_session_run() {
  session_count=$1
  session_mode=$2
  session_index=1
  while [ "$session_index" -le "$session_count" ]; do
    if [ "$session_mode" = instrumented ]; then
      runtime_benchmark_wrapper_run rg --version >/dev/null
    else
      runtime_benchmark_wrapper_uninstrumented_run rg --version >/dev/null
    fi
    session_index=$((session_index + 1))
  done
  session_index=1
  while [ "$session_index" -le "$session_count" ]; do
    if [ "$session_mode" = instrumented ]; then
      runtime_benchmark_wrapper_run jq --version >/dev/null
    else
      runtime_benchmark_wrapper_uninstrumented_run jq --version >/dev/null
    fi
    session_index=$((session_index + 1))
  done
}

runtime_benchmark_jq_individual_run() {
  (
    cd -- "$OUTPUT_DIR/fixtures"
    for fixture_file in ./*.json; do
      runtime_benchmark_wrapper_run jq -c . "$fixture_file"
    done
  )
}

runtime_benchmark_jq_batched_run() {
  (
    cd -- "$OUTPUT_DIR/fixtures"
    runtime_benchmark_wrapper_run jq -c . ./record-1.json ./record-2.json ./record-3.json ./record-4.json
  )
}

runtime_benchmark_workload_run() {
  case "$1" in
    shell-selection) runtime_benchmark_shell_selection_run ;;
    activation-dry-run) "$PROFILE_LAUNCHER" profile activate "$ACTIVE_PROFILE" --dry-run ;;
    rg-version) runtime_benchmark_wrapper_run rg --version ;;
    jq-version) runtime_benchmark_wrapper_run jq --version ;;
    jq-individual) runtime_benchmark_jq_individual_run ;;
    jq-batched) runtime_benchmark_jq_batched_run ;;
    preflight-current) runtime_benchmark_preflight_current_run ;;
    preflight-context-review) runtime_benchmark_preflight_context_review_run ;;
    profile-affinity-current) runtime_benchmark_profile_affinity_current_run ;;
    preflight-reachability-review) runtime_benchmark_preflight_reachability_review_run ;;
    preflight-installed) runtime_benchmark_preflight_installed_run ;;
    affinity-installed) runtime_benchmark_affinity_installed_run ;;
    probe-machine-list) runtime_benchmark_probe_machine_list_run ;;
    probe-connection-list) runtime_benchmark_probe_connection_list_run ;;
    probe-workload-ps) runtime_benchmark_probe_workload_ps_run ;;
    probe-info-unqualified) runtime_benchmark_probe_info_unqualified_run ;;
    probe-info-explicit) runtime_benchmark_probe_info_explicit_run ;;
    direct-rg) runtime_benchmark_direct_rg_run ;;
    direct-jq) runtime_benchmark_direct_jq_run ;;
    rg-version-uninstrumented) runtime_benchmark_wrapper_uninstrumented_run rg --version ;;
    jq-version-uninstrumented) runtime_benchmark_wrapper_uninstrumented_run jq --version ;;
    minimum-association) runtime_benchmark_minimum_association_run ;;
    session-40x40) runtime_benchmark_session_run "$SESSION_COMMAND_COUNT" instrumented ;;
    session-40x40-uninstrumented) runtime_benchmark_session_run "$SESSION_COMMAND_COUNT" uninstrumented ;;
    session-200x200) runtime_benchmark_session_run "$SENSITIVITY_COMMAND_COUNT" instrumented ;;
    *) printf 'ERROR: unknown benchmark workload: %s\n' "$1" >&2; return 2 ;;
  esac
}

runtime_benchmark_single_sample_measure() {
  lane=$1
  : > "$RAW_DIR/$lane.samples"
  runtime_benchmark_command_run "$lane"
  runtime_benchmark_lane_summary_write "$lane"
}

runtime_benchmark_events_collect() {
  event_name=shimmy-runtime-benchmark-events-$$
  event_start=$(date +%s)
  set +e
  "$REAL_PODMAN" --connection "$EXPECTED_CONNECTION" run --rm --name "$event_name" -i \
    --platform "$BENCHMARK_PLATFORM" -v "$PWD:/work" -w /work "$JQ_IMAGE" --version \
    > "$RAW_DIR/events-smoke.stdout" 2> "$RAW_DIR/events-smoke.stderr"
  event_smoke_status=$?
  event_end=$(date +%s)
  "$REAL_PODMAN" --connection "$EXPECTED_CONNECTION" events \
    --since "$event_start" --until "$((event_end + 2))" \
    --filter "container=$event_name" --format '{{.Time}}|{{.Status}}|{{.Name}}' \
    > "$RAW_DIR/container-events.txt" 2> "$RAW_DIR/container-events.stderr"
  event_query_status=$?
  set -e
  event_count=$(wc -l < "$RAW_DIR/container-events.txt" | tr -d ' ')
  printf 'event_smoke_status=%s event_query_status=%s event_count=%s\n' \
    "$event_smoke_status" "$event_query_status" "$event_count" >> "$OUTPUT_DIR/summary.txt"
}

runtime_benchmark_extended_measure() {
  "$REAL_PODMAN" image exists "$RG_IMAGE"
  "$REAL_PODMAN" image exists "$JQ_IMAGE"

  for lane in \
    preflight-installed \
    affinity-installed \
    probe-machine-list \
    probe-connection-list \
    probe-workload-ps \
    probe-info-unqualified \
    probe-info-explicit \
    direct-rg \
    direct-jq \
    rg-version-uninstrumented \
    jq-version-uninstrumented \
    minimum-association
  do
    runtime_benchmark_lane_measure "$lane"
    runtime_benchmark_lane_summary_write "$lane"
  done

  cmp -s "$RAW_DIR/probe-info-unqualified.stdout" "$RAW_DIR/probe-info-explicit.stdout" || {
    printf '%s\n' 'ERROR: unqualified and explicit-connection Podman info identify different targets.' >&2
    exit 1
  }
  printf '%s\n' 'connection_probe_targets_equivalent=true' >> "$OUTPUT_DIR/summary.txt"

  runtime_benchmark_single_sample_measure session-40x40
  runtime_benchmark_single_sample_measure session-40x40-uninstrumented
  runtime_benchmark_single_sample_measure session-200x200
  runtime_benchmark_events_collect
}

runtime_benchmark_review_measure() {
  for lane in \
    preflight-current \
    preflight-context-review \
    profile-affinity-current \
    preflight-reachability-review
  do
    runtime_benchmark_lane_measure "$lane"
    runtime_benchmark_lane_summary_write "$lane"
  done
}

runtime_benchmark_main() {
  if [ "${1:-}" = --internal-workload ]; then
    [ "$#" -eq 2 ] || exit 2
    runtime_benchmark_workload_run "$2"
    return
  fi

  runtime_benchmark_options_parse "$@"
  runtime_benchmark_active_profile_discover
  runtime_benchmark_output_prepare
  runtime_benchmark_podman_proxy_create
  runtime_benchmark_provenance_write
  export ACTIVE_PROFILE PROFILE_ROOT PROFILE_LAUNCHER PROFILE_SHELL_INIT OUTPUT_DIR
  export EXPECTED_CONNECTION EXPECTED_MACHINE RG_IMAGE JQ_IMAGE
  export BENCHMARK_PLATFORM
  export SESSION_COMMAND_COUNT SENSITIVITY_COMMAND_COUNT

  : > "$OUTPUT_DIR/summary.txt"
  if [ "$REVIEW_ONLY" -eq 1 ]; then
    runtime_benchmark_review_measure
    printf 'output_dir=%s\n' "$OUTPUT_DIR"
    cat "$OUTPUT_DIR/summary.txt"
    return 0
  fi
  if [ "$EXTENDED_ONLY" -eq 1 ]; then
    runtime_benchmark_extended_measure
    printf 'output_dir=%s\n' "$OUTPUT_DIR"
    cat "$OUTPUT_DIR/summary.txt"
    return 0
  fi

  runtime_benchmark_fixture_create
  runtime_benchmark_lane_measure shell-selection
  : > "$RAW_DIR/activation-dry-run.samples"
  runtime_benchmark_command_run activation-dry-run
  runtime_benchmark_lane_measure rg-version
  runtime_benchmark_lane_measure jq-version
  runtime_benchmark_lane_measure jq-individual
  runtime_benchmark_lane_measure jq-batched

  runtime_benchmark_jq_individual_run > "$RAW_DIR/jq-individual.records"
  runtime_benchmark_jq_batched_run > "$RAW_DIR/jq-batched.records"
  sort "$RAW_DIR/jq-individual.records" > "$RAW_DIR/jq-individual.sorted"
  sort "$RAW_DIR/jq-batched.records" > "$RAW_DIR/jq-batched.sorted"
  cmp -s "$RAW_DIR/jq-individual.sorted" "$RAW_DIR/jq-batched.sorted" || {
    printf '%s\n' 'ERROR: individual and batched jq results differ.' >&2
    exit 1
  }

  for lane in shell-selection activation-dry-run rg-version jq-version jq-individual jq-batched; do
    runtime_benchmark_lane_summary_write "$lane"
  done
  printf 'output_dir=%s\n' "$OUTPUT_DIR"
  cat "$OUTPUT_DIR/summary.txt"
}

runtime_benchmark_main "$@"
