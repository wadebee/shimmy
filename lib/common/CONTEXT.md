# Common helpers

`common.sh` contains generic list, manifest, quoting, strict safe-name/version,
Git identity, SHA-256, normalized absolute-path, lexical-list, encoding, and
diagnostic-redaction helpers. Keep it free of profile location and tool policy.

`lock.sh` atomically claims complete regular owner records, enforces catalog,
activation, lexical profile, then registry order, releases in reverse, and
removes only exactly revalidated dead-owner records. Cleanup releases only
claims owned by the current process.
