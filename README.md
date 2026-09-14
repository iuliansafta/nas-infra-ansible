# NAS infrastructure

Production-minded Ansible for an Ubuntu 26.04 family NAS. It manages the host, an existing ZFS pool, Samba, Docker/Immich, Home Assistant, Tailscale, snapshots, SMART and optional backups/Scrutiny. It does **not** manage Git on the target host or contain secrets.

## Safe start

1. Install Ubuntu and prove initial SSH access.
2. Install Ansible collections: `ansible-galaxy collection install -r requirements.yml`.
3. Replace every placeholder in `inventory/home.yml` and `inventory/group_vars/all/all.yml`.
4. Copy `inventory/vault.example.yml` to `inventory/group_vars/all/vault.yml`, replace every placeholder, and immediately run `ansible-vault encrypt inventory/group_vars/all/vault.yml`. The destination matters: a `group_vars/<name>` file is only loaded when a group named `<name>` exists, and this inventory has no `vault` group, so any other path is imported as nothing at all.
5. Point the inventory at the temporary installer-created administrator and run `make bootstrap`. Then switch `ansible_user` to the new automation user. In a second terminal prove its public-key login and passwordless sudo; only then set both SSH hardening flags.
6. Leave `firewall_enabled: false` until the real trusted LAN CIDR is configured and SSH access from that CIDR is proven. Then run `make check` and `make apply`.

`make preflight` validates that no placeholder or empty value survives in the configuration required by the features you have enabled (`site.yml` runs it automatically before any role). Optional features left off are not checked, so they stay valid while unconfigured.

Normal `site.yml` never creates a pool: it only imports an existing named pool and manages datasets. For first-time storage, collect and review `lsblk -O`, SMART output, serials and `/dev/disk/by-id` links. Configure exactly two whole-disk by-id paths and set the exact `zfs_storage_confirmation` string only after reviewing those facts, then invoke `make storage-init`. This is destructive and uses `zpool create -f`; never run it against a pool or disks containing data. `make storage` is only for importing/configuring a pool that already exists.

Immich binds to loopback by default. Select a LAN or Tailscale address deliberately if clients need direct access; never publish on `0.0.0.0` without separately tested Docker-aware filtering. UFW alone does not filter Docker-published ports. Scrutiny likewise binds to loopback. Netplan only renders and validates when enabled; apply it with `netplan try` from a console.

Home Assistant keeps `network_mode: host` for mDNS discovery, but its HTTP listener is bound to loopback and published through Tailscale Serve, so it is reachable only on the tailnet — the same posture as Immich. It is served at `https://nas.<tailnet>.ts.net:8443`, because Immich already owns port 443 and Home Assistant cannot run under a subpath. The loopback bind and the `trusted_proxies` block are written by the role straight into Home Assistant's config store (`/config/.storage/http`), **not** into YAML: Home Assistant stages an `http:` block from YAML as an unconfirmed trial that auto-reverts after five minutes, which on a fresh install silently returns the listener to `0.0.0.0`.

Before enabling backups, mount the removable filesystem at `backup_mount`, configure and encrypt the vault, and initialize the restic repository once with `set -a; . /etc/nas-backup.env; set +a; restic init`. Automated jobs deliberately refuse to initialize a repository, so authentication or connectivity failures cannot be mistaken for a new repository.

See [recovery](docs/RECOVERY.md) and [acceptance checks](docs/ACCEPTANCE.md). Read Immich release notes before changing `immich_version`; create a DB backup first and validate login, upload and asset access afterward. Home Assistant upgrades migrate the recorder database irreversibly: take the config archive first, then change only `homeassistant_version` and validate login and automations.

## Local-only documents

`PLAN.md`, `plan_ubuntu_26_04.md` and `docs/MIGRATION.md` are design and migration planning kept on the author's machine only. They are gitignored and deliberately absent from this repository, so the links above are the tracked documentation set.
