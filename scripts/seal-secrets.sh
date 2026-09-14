#!/usr/bin/env bash
# Seal the secrets for this host into the Ansible Vault.
#
# 1Password stays the source of truth for producing secrets; the vault is what
# playbooks read at runtime. Nothing is written unless every reference reads
# successfully, so a half-sealed vault cannot be left behind.
#
#   make seal          # or: scripts/seal-secrets.sh
#
# The encrypted result is committed to git. The master password is not in this
# repository - see scripts/vault-pass.sh.
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TARGET="$REPO_ROOT/inventory/group_vars/all/vault.yml"

# Pin the account explicitly: with several accounts signed in, bare `op`
# resolves against the wrong one.
OP_ACCOUNT='my.1password.com'

# Point ansible-vault at this repository's config rather than whatever it would
# find from the current directory. That config sets vault_password_file, which
# is the single source of truth for the master password - passing
# --vault-password-file here as well would declare two vault identities and
# ansible-vault would abort with "vault-ids default,default are available".
export ANSIBLE_CONFIG="$REPO_ROOT/ansible.cfg"

# Item references are by name because they are self-documenting. Renaming an
# item in 1Password breaks the reference; that fails loudly below rather than
# sealing the wrong value. Add one samba entry per household user in nas_users.
SAMBA_USER='iuliansafta'
SAMBA_REF='op://Homelab/nas-thonon Samba/password'
IMMICH_REF='op://Homelab/nas-thonon Immich DB/password'
RESTIC_REF='op://Homelab/nas-thonon Restic/password'

RAW=''
TMP_PLAIN=''
TMP_OUT=''
cleanup() {
  # ${VAR:-} because RAW is unset on the success path and this runs under set -u.
  [ -n "${TMP_PLAIN:-}" ] && rm -f "${TMP_PLAIN}"
  [ -n "${TMP_OUT:-}" ] && rm -f "${TMP_OUT}"
  [ -n "${MISSING_FILE:-}" ] && rm -f "${MISSING_FILE}"
  unset RAW
  return 0
}
trap cleanup EXIT

die() { printf 'seal-secrets: %s\n' "$*" >&2; exit 1; }

command -v op >/dev/null 2>&1 \
  || die "the 1Password CLI (op) is not installed or not on PATH."

# Read one reference, recording failures instead of aborting, so a single run
# reports every broken reference at once. The list is kept in a file because
# read_secret is called inside a command substitution: an array append would
# happen in that subshell and be lost, silently disabling the check below.
MISSING_FILE=$(mktemp)
read_secret() {
  local ref=$1 out
  if ! out=$(op read --account "$OP_ACCOUNT" --no-newline "$ref" 2>&1); then
    printf '%s\n' "$ref" >> "$MISSING_FILE"
    printf 'seal-secrets: cannot read %s\n' "$ref" >&2
    printf '    %s\n' "${out#*[ERROR] }" >&2
    return 1
  fi
  printf '%s' "$out"
}

printf 'Reading secrets from %s\n' "$OP_ACCOUNT"
SAMBA_PW=$(read_secret "$SAMBA_REF") || true
IMMICH_PW=$(read_secret "$IMMICH_REF") || true
RESTIC_PW=$(read_secret "$RESTIC_REF") || true

if [ -s "$MISSING_FILE" ]; then
  printf '\nseal-secrets: %s of 3 references failed; nothing was written.\n' "$(wc -l < "$MISSING_FILE")" >&2
  printf 'Check the account (`op account list`) and that each item still exists.\n' >&2
  exit 1
fi

# Single-quoted YAML scalars are safe for any single-line value: only a quote
# needs doubling. A control character is refused outright because YAML would
# fold an embedded newline, silently corrupting the secret.
yaml_scalar() {
  local value=$1 name=$2
  if printf '%s' "$value" | LC_ALL=C grep -q '[[:cntrl:]]'; then
    die "the value for $name contains a control character; refusing to seal it."
  fi
  if [ -z "$value" ]; then
    die "the value for $name is empty."
  fi
  printf "'%s'" "${value//\'/\'\'}"
}

# Escaped before the render so that yaml_scalar runs directly: `die` inside a
# command substitution would only exit a subshell and lose its error path.
SAMBA_Y=$(yaml_scalar "$SAMBA_PW" "$SAMBA_REF")
IMMICH_Y=$(yaml_scalar "$IMMICH_PW" "$IMMICH_REF")
RESTIC_Y=$(yaml_scalar "$RESTIC_PW" "$RESTIC_REF")

RAW=$(
  printf -- '---\n'
  printf 'samba_passwords:\n'
  printf '  %s: %s\n' "$SAMBA_USER" "$SAMBA_Y"
  printf 'immich_db_password: %s\n' "$IMMICH_Y"
  printf 'restic_password: %s\n' "$RESTIC_Y"
)

TMP_PLAIN=$(mktemp)
chmod 600 "$TMP_PLAIN"
printf '%s\n' "$RAW" > "$TMP_PLAIN"
unset RAW

# The password comes from vault_password_file in the config above, never from an
# interactive prompt. If that setting is missing, ansible-vault would try to
# prompt and fail with a bare EOFError, so the message below names it.
TMP_OUT=$(mktemp -p "$(dirname "$TARGET")" .vault.yml.XXXXXX)
ansible-vault encrypt --output "$TMP_OUT" "$TMP_PLAIN" </dev/null \
  || die "ansible-vault encrypt failed. Check vault_password_file in ansible.cfg and the 1Password account."
mv -f "$TMP_OUT" "$TARGET"
TMP_OUT=''

printf 'Sealed 3 secrets into %s\n' "${TARGET#"$REPO_ROOT"/}"
printf 'Verify with `make preflight`.\n'
