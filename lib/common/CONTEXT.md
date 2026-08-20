# Common helpers

`common.sh` contains generic list, manifest, quoting, and path helpers shared
by management commands. Target-only helpers add strict lowercase name and Git
identity grammars, SHA-256 file identities, normalized absolute-path checks,
lexical list validation, and reversible public-manifest encoding with explicit
diagnostic redaction. Keep this module free of profile-location and
tool-runtime policy.
