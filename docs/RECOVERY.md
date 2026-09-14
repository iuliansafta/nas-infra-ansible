# Recovery runbook

## NVMe failure
Reinstall Ubuntu 26.04 on replacement NVMe, enable SSH, restore this repository and vault, run bootstrap, import with `zpool import -d /dev/disk/by-id tank`, then run site. Restore the newest SQL dump with Immich stopped except PostgreSQL: decompress it and pipe to `docker exec -i immich_postgres psql -U postgres -d immich`. Start Compose and verify users, counts and representative assets. Never restore a live raw PostgreSQL directory as the primary method.

## One HDD failure
Record `zpool status -P`, SMART and by-id identities. Offline/replace only the failed serial: `zpool replace tank OLD_BY_ID NEW_BY_ID`. Monitor `zpool status`; after resilver run a scrub and SMART tests. Commands are examples—review exact pool output before execution.

## Complete loss / restic
Rebuild host, initialize new storage only through reviewed preflight, export `RESTIC_REPOSITORY` and `RESTIC_PASSWORD`, run `restic check`, restore to a staging directory, inspect it, then copy photos/documents/dumps into datasets. Restore SQL as above. Test one document, one photo, login, upload, shares and permissions.
