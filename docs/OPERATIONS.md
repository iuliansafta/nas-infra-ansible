# Operations

Before changes record:

```bash
lsb_release -a
uname -a
lscpu
free -h
ip -br link
ip -br addr
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
lspci -nn
ls -l /dev/dri
smartctl --scan
zfs version
zpool status
docker version
docker compose version
systemctl --failed
```

Review ZFS health, capacity, SMART temperatures, Docker health, journals, and the backup timer routinely. Snapshots are not backups. Never run `zpool upgrade` automatically.

For Immich upgrades: run `/usr/local/sbin/immich-db-backup`, read release notes and required intermediate versions, change only the pinned variable, apply, then validate container health, login, upload and assets. Do not use blind automatic upgrades.

For Home Assistant upgrades: run `/usr/local/sbin/homeassistant-config-backup`, read the release notes, change only `homeassistant_version`, apply, then validate container health, login and automations. Recorder database migrations are irreversible, so the config archive is the only rollback path. The HTTP listener is bound to `127.0.0.1` and reached through Tailscale Serve; confirm `tailscale serve status` still shows `/` proxying to `http://127.0.0.1:8123`, that `ss -tln | grep 8123` shows only `127.0.0.1` and never `0.0.0.0`, and that `http://<lan-ip>:8123` is refused. To add a Zigbee or Z-Wave radio, stop the container, add the stable `/dev/serial/by-id/...` path to `homeassistant_serial_devices`, and apply — never a `/dev/ttyUSB*` name, which moves between boots. The recorder database and logs are excluded from the config archive by design; tune history retention inside Home Assistant rather than pruning the NVMe by hand.

The HTTP listener settings live in Home Assistant's config store at `/config/.storage/http`, written by the `homeassistant` role, and not in YAML. Home Assistant stages an `http:` block from YAML as an unconfirmed trial that auto-reverts after five minutes; a fresh install has no logged-in user to confirm it, so the loopback bind silently reverts to `0.0.0.0`. A reverted store also loses `use_x_forwarded_for`, and Home Assistant's `http.forwarded` middleware then rejects every proxied request with `400: Bad Request` - which is what breaks onboarding through Tailscale Serve. Two invariants when editing that file: keep `pending` present and `null`, because the loader indexes it directly and the whole `http` component fails to set up without it, and keep `yaml_migration_done` true so YAML is never re-migrated. If you change these settings in the Home Assistant UI, mirror them into the role or the next apply will overwrite them.

Tailscale Serve entries for Immich and Home Assistant are rendered from `immich_serve_port` and `homeassistant_serve_port`, so applying the tailscale role re-asserts them, and Immich's entry is a no-op when it already matches. They are deliberately not removed automatically: after disabling an application, unpublish it with `tailscale serve --https=<port> off`.

For QSV, enable `/dev/dri` only after it exists, select Quick Sync in Immich's transcoding settings, perform a real transcode, and inspect logs, GPU activity and CPU use. Device presence alone is not proof of acceleration.

For backups, mount the removable disk deliberately, verify `mountpoint /mnt/backup`, initialize restic once, then enable the timer. Inspect `journalctl -u nas-restic-backup`, run `restic check`, and perform document, photo, and database restores. The local SQL/config archives are retained for up to one year; restic enforces 7 daily, 4 weekly, and 12 monthly snapshots.
