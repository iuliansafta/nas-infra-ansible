#!/usr/bin/env bash
# Ansible vault password script.
#
# Ansible executes any vault password file that has the executable bit set and
# uses its stdout as the password, so the master password only ever exists in
# 1Password and in Ansible's memory. Requested via ansible.cfg:
#   vault_password_file = scripts/vault-pass.sh
#
# Nothing is cached on disk on purpose. If 1Password is unavailable or locked,
# every command that needs vault data fails here with the reason, rather than
# handing Ansible an empty password (which produces a misleading decryption
# error instead).
set -euo pipefail

# Pin the account explicitly: with several accounts signed in, bare `op`
# resolves against the wrong one.
OP_ACCOUNT='my.1password.com'
OP_REF='op://Homelab/nas-thonon Ansible Vault/password'

if ! command -v op >/dev/null 2>&1; then
  printf 'vault-pass: the 1Password CLI (op) is not installed or not on PATH.\n' >&2
  exit 1
fi

if ! password=$(op read --account "$OP_ACCOUNT" --no-newline "$OP_REF" 2>&1); then
  printf 'vault-pass: cannot read the vault master password from 1Password.\n' >&2
  printf '  account: %s\n' "$OP_ACCOUNT" >&2
  printf '  item:    %s\n' "$OP_REF" >&2
  printf '  detail:  %s\n' "$password" >&2
  printf 'Run `op signin --account %s` and retry.\n' "$OP_ACCOUNT" >&2
  exit 1
fi

if [ -z "$password" ]; then
  printf 'vault-pass: 1Password returned an empty password for %s\n' "$OP_REF" >&2
  exit 1
fi

printf '%s' "$password"
