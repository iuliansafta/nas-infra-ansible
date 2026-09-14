# NAS infrastructure

Production-minded Ansible for an Ubuntu 26.04 family NAS. It manages the host, an existing ZFS pool, Samba, Docker/Immich, Home Assistant, Tailscale, snapshots, SMART and optional backups/Scrutiny. It does **not** manage Git on the target host. The only secret material it stores is the encrypted Ansible Vault — see [Secrets](#secrets).

## Safe start

1. Install Ubuntu and prove initial SSH access.
2. Install Ansible collections: `ansible-galaxy collection install -r requirements.yml`.
3. Replace every placeholder in `inventory/home.yml` and `inventory/group_vars/all/all.yml`.
4. Seal the secrets into the vault: `make seal`. It reads the `nas-thonon Samba`, `nas-thonon Immich DB` and `nas-thonon Restic` items from the personal 1Password account and writes `inventory/group_vars/all/vault.yml`. Nothing is written unless every reference reads successfully, so a half-sealed vault is not possible.
5. Point the inventory at the temporary installer-created administrator and run `make bootstrap`. Then switch `ansible_user` to the new automation user. In a second terminal prove its public-key login and passwordless sudo; only then set both SSH hardening flags.
6. Leave `firewall_enabled: false` until the real trusted LAN CIDR is configured and SSH access from that CIDR is proven. Then run `make check` and `make apply`.
7. Tailscale enrollment is not automated. On a fresh host run `sudo tailscale up` once and approve it in the browser; the Serve entries can only be published after that.

`make preflight` validates that no placeholder or empty value survives in the configuration required by the features you have enabled (`site.yml` runs it automatically before any role). Optional features left off are not checked, so they stay valid while unconfigured.

`make verify` goes further and exercises each sealed secret against the service that consumes it on a live host: that the deployed Immich `.env` matches the vault and its password authenticates to `immich_postgres`, that Immich answers over HTTP, that the Samba password authenticates over the network, and — when `enable_backup` is set — that the restic password opens the repository. It is read-only on the NAS and exits non-zero if any check fails. A check that cannot run is reported as `SKIP` with its reason, never as a pass, so a missing tool cannot masquerade as a healthy secret — but a skip does not fail the run, so read the summary rather than only the exit status. Run it after `make seal` or after any change to a 1Password item.

Normal `site.yml` never creates a pool: it only imports an existing named pool and manages datasets. For first-time storage, collect and review `lsblk -O`, SMART output, serials and `/dev/disk/by-id` links. Configure exactly two whole-disk by-id paths and set the exact `zfs_storage_confirmation` string only after reviewing those facts, then invoke `make storage-init`. This is destructive and uses `zpool create -f`; never run it against a pool or disks containing data. `make storage` is only for importing/configuring a pool that already exists.

Immich binds to loopback by default. Select a LAN or Tailscale address deliberately if clients need direct access; never publish on `0.0.0.0` without separately tested Docker-aware filtering. UFW alone does not filter Docker-published ports. Scrutiny likewise binds to loopback. Netplan only renders and validates when enabled; apply it with `netplan try` from a console.

Home Assistant keeps `network_mode: host` for mDNS discovery, but its HTTP listener is bound to loopback and published through Tailscale Serve, so it is reachable only on the tailnet — the same posture as Immich. It is served at `https://nas.<tailnet>.ts.net:8443`, because Immich already owns port 443 and Home Assistant cannot run under a subpath. The loopback bind and the `trusted_proxies` block are written by the role straight into Home Assistant's config store (`/config/.storage/http`), **not** into YAML: Home Assistant stages an `http:` block from YAML as an unconfirmed trial that auto-reverts after five minutes, which on a fresh install silently returns the listener to `0.0.0.0`.

Before enabling backups, mount the removable filesystem at `backup_mount`, seal the vault with `make seal`, and initialize the restic repository once with `set -a; . /etc/nas-backup.env; set +a; restic init`. Automated jobs deliberately refuse to initialize a repository, so authentication or connectivity failures cannot be mistaken for a new repository.

See [recovery](docs/RECOVERY.md) and [acceptance checks](docs/ACCEPTANCE.md). Read Immich release notes before changing `immich_version`; create a DB backup first and validate login, upload and asset access afterward. Home Assistant upgrades migrate the recorder database irreversibly: take the config archive first, then change only `homeassistant_version` and validate login and automations.

## Secrets

Three secrets are read at runtime, and all three come from the encrypted vault at `inventory/group_vars/all/vault.yml`. That file is committed, because it is unreadable without the master password.

| Variable | 1Password item |
|---|---|
| `samba_passwords.iuliansafta` | `nas-thonon Samba` |
| `immich_db_password` | `nas-thonon Immich DB` |
| `restic_password` | `nas-thonon Restic` |

1Password is the source of truth for *producing* secrets, but nothing is read from it while a playbook runs. To rotate a value, change the item in 1Password and run `make seal`. Adding a household user also needs a matching entry in `scripts/seal-secrets.sh`; `make preflight` fails if a user in `nas_users` has no password.

The master password is the `nas-thonon Ansible Vault` item in the `my.1password.com` account, pinned explicitly in `scripts/vault-pass.sh` because `op` resolves against the wrong account when several are signed in. It supplies the password to `ansible-playbook` and `ansible-vault` alike, so no command needs `--ask-vault-pass` and the password is never cached on disk. The cost is that every command touching vault data needs `op` authenticated on the controller.

The `Vault` item in the same 1Password vault is HashiCorp Vault (`:8200`), not this repository's vault, and is unrelated.

Losing the `nas-thonon Ansible Vault` item makes the vault unreadable and the restic backups unrecoverable. Keep it covered by the 1Password account's recovery kit.

## Local-only documents

`PLAN.md`, `plan_ubuntu_26_04.md` and `docs/MIGRATION.md` are design and migration planning kept on the author's machine only. They are gitignored and deliberately absent from this repository, so the links above are the tracked documentation set.
