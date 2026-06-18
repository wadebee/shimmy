#!/bin/sh
set -eu

python - <<'PY'
import json
import os
from pathlib import Path

config_dir = Path(os.environ.get("HOME", "/root")) / ".opnsense-mcp"
config_file = config_dir / "config.json"
verify_ssl = os.environ.get("OPNSENSE_VERIFY_SSL", "true").lower() in ("true", "1", "yes")

config_dir.mkdir(mode=0o700, parents=True, exist_ok=True)
config_data = {
    "default": {
        "url": os.environ.get("OPNSENSE_URL", ""),
        "api_key": "environment-provided",
        "api_secret": "environment-provided",
        "verify_ssl": verify_ssl,
    }
}

with config_file.open("w", encoding="utf-8") as handle:
    json.dump(config_data, handle, indent=2)
    handle.write("\n")

config_file.chmod(0o600)
PY

exec opnsense-mcp-server "$@"
