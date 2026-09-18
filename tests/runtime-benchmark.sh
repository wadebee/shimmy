#!/bin/sh
set -eu

SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
SAMPLE_COUNT=20
WARMUP_COUNT=3
OUTPUT_DIR=${OUTPUT_DIR:-}

runtime_benchmark_usage() {
  cat <<'EOF'
Usage: ./tests/runtime-benchmark.sh [--samples <count>] [--warmups <count>] [--output <directory>]

Measures the selected installed profile's shell selection, activation dry run,
and rg/jq wrapper workloads. The benchmark creates only private JSON fixtures
and a transparent temporary Podman forwarding script. It does not activate a
profile, change a Podman connection, pull images, or build images.
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
  {
    printf 'source_commit=%s\n' "$(git -C "$ROOT_DIR" rev-parse HEAD)"
    printf 'active_profile=%s\n' "$ACTIVE_PROFILE"
    printf 'profile_root=%s\n' "$PROFILE_ROOT"
    printf 'host_os=%s\n' "$(uname -s)"
    printf 'host_arch=%s\n' "$(uname -m)"
    printf 'podman_bin=%s\n' "$REAL_PODMAN"
    printf 'podman_version=%s\n' "$("$REAL_PODMAN" version --format '{{.Client.Version}}' 2>/dev/null || printf unavailable)"
    printf 'profile_control_commit=%s\n' "$(runtime_benchmark_value_read "$PROFILE_ROOT/install-manifest.txt" shimmy_profile_control_commit)"
    printf 'default_connection=%s\n' "$("$REAL_PODMAN" system connection list --format '{{range .}}{{if .Default}}{{.Name}}{{end}}{{end}}' 2>/dev/null || printf unavailable)"
    printf 'rootless_socket=%s\n' "${XDG_RUNTIME_DIR:-unavailable}/podman/podman.sock"
    if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/podman/podman.sock" ]; then
      printf '%s\n' 'rootless_socket_present=true'
    else
      printf '%s\n' 'rootless_socket_present=false'
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

runtime_benchmark_shell_selection_run() {
  PATH="$OUTPUT_DIR/bin:$PATH"
  export PATH
  . "$PROFILE_SHELL_INIT"
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
    *) printf 'ERROR: unknown benchmark workload: %s\n' "$1" >&2; return 2 ;;
  esac
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
  runtime_benchmark_fixture_create
  export ACTIVE_PROFILE PROFILE_LAUNCHER PROFILE_SHELL_INIT OUTPUT_DIR

  : > "$OUTPUT_DIR/summary.txt"
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
