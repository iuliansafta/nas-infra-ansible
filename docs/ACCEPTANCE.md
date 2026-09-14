# Acceptance checklist

- [ ] Ubuntu 26.04.x, versions and hardware inventory recorded
- [ ] SSH key and sudo proven before hardening; reboot and second Ansible run succeed
- [ ] `site.yml --check --diff` shows no destructive storage operation
- [ ] Mirror uses the two reviewed by-id disks; pool healthy/imports; dataset properties match plan
- [ ] Snapshot restore and monthly scrub tested
- [ ] Private SMB isolation and shared RW tested on macOS/Linux/iOS, LAN and Tailscale
- [ ] No service reachable from an untrusted network; PostgreSQL/Docker socket not published
- [ ] Two Immich accounts; upload/HEIC/Live Photo/video and reboot tested
- [ ] Originals on ZFS; PostgreSQL on NVMe; QSV transcode verified if enabled
- [ ] Home Assistant owner account created; reachable at `https://nas.<tailnet>.ts.net:8443`; `http://<lan-ip>:8123` refused
- [ ] Home Assistant config archive restored into a scratch directory; USB radio path survives re-plug and reboot if configured
- [ ] SMART tests/temperatures and sustained-I/O thermals reviewed
- [ ] DB dump and restic snapshot generated; `restic check` passes
- [ ] One document, photo and DB restore tested
- [ ] No plaintext secrets; no router forwarding/public exposure
