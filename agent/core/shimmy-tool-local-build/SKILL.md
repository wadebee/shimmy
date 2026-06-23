# shimmy-tool-local-build

## Purpose
Provides guidance for enabling and managing local image builds for Shimmy concrete version shims that require directory-based container construction.

## Usage
1. **For new version shims**: Add to `local_build_repo_for_shim` in `scripts/update-shimmy.sh` with format:
   ```sh
   <kind>_<major>_<minor>) printf 'localhost/shimmy-<kind>-<major>_<minor>\n' ;;
   ```
2. **Containerfile requirements**: Ensure version shims have a valid `images/<kind>_<major>_<minor>/Containerfile`.
3. **Cleanup automation**: New version shims should participate in `cleanup_old_local_images` cleanup logic through their versioned local image repo.

## Example
For opnsense-mcp version shims:
```sh
# In scripts/update-shimmy.sh
local_build_repo_for_shim() {
  case "$1" in
    # ... existing cases ...
    opnsense-mcp-admin_1_0) printf 'localhost/shimmy-opnsense-mcp-admin-1_0\n' ;;
    opnsense-mcp-read-only_0_4) printf 'localhost/shimmy-opnsense-mcp-read-only-0_4\n' ;;
  esac
}
```

## Validation
Run `cleanup_old_local_images opnsense-mcp-admin_1_0` to verify cleanup targets are generated.
