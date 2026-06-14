# shimmy-tool-local-build

## Purpose
Provides guidance for enabling and managing local image builds for Shimmy shims that require directory-based container construction.

## Usage
1. **For new shims**: Add to `local_build_repo_for_shim` in `scripts/update-shimmy.sh` with format:
   ```sh
   <shim-name>) printf 'localhost/<shim-name>\n' ;;
   ```
2. **Containerfile requirements**: Ensure shims have a valid Dockerfile/Containerfile in `shims/<shim>/`.
3. **Cleanup automation**: New shims will automatically appear in `cleanup_old_local_images` cleanup logic.

## Example
For opnsense-mcp shims:
```sh
# In scripts/update-shimmy.sh
local_build_repo_for_shim() {
  case "$1" in
    # ... existing cases ...
    opnsense-mcp-admin) printf 'localhost/shimmy-opnsense-mcp-admin\n' ;;
    opnsense-mcp-read-only) printf 'localhost/shimmy-opnsense-mcp-read-only\n' ;;
  esac
}
```

## Validation
Run `cleanup_old_local_images opnsense-mcp-admin` to verify cleanup targets are generated.