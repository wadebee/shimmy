# Common helpers

`common.sh` contains generic list, manifest, quoting, and path helpers shared
by management commands. Target-only helpers add strict lowercase name and Git
identity grammars, SHA-256 file identities, normalized absolute-path checks,
lexical list validation, and reversible public-manifest encoding with explicit
diagnostic redaction. The generic non-symlink parent-chain check also lives
here so target transactions do not depend on current profile policy.

`lock.sh` is private target-only code. It claims complete regular lock-owner
records atomically with same-directory hard links, enforces catalog,
activation, lexical profile, then registry ordering, releases in reverse, and
removes only exact dead-owner records after quarantine revalidation. Cleanup
handlers release exact owned claims across normal exit and HUP/INT/TERM.
Keep these modules free of profile-location and tool-runtime policy.
