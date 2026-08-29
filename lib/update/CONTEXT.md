# Profile synchronization

`profile.sh` implements active invoking-profile `sync` and exact-ledger startup
repair. Sync fetches the recorded source, requires `refs/heads/main`, snapshots
current default-catalog authority, stages a complete profile replacement before
locks, preserves startup/redirect bytes and explicit shim policies, revalidates
source/catalog/active/registry authority, then commits the manifest last.

Startup repair writes only the invoking profile's recorded managed paths with
exact rollback and is a no-op for manual policy. There is no separate update
command, management self-update route, or compatibility selection layer.

Sync preserves an existing engine binding byte-for-byte while installing the
complete strict control tree. It never creates or converts engine state.
