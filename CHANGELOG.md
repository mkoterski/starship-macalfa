# Changelog

All notable changes to starship-macalfa.

## [Unreleased] — 2026-03-30

### Changed — Repository Restructure

Restructured from a full HarbourMasters/Starship fork to a **scripts-only
wrapper** repository. The upstream source is now cloned at build time,
matching the [perfectdark-macvanta](https://github.com/mkoterski/perfectdark-macvanta)
conventions.

**What changed:**

* **No more fork** — upstream `HarbourMasters/Starship` is cloned into `Starship/`
  by `smca-build-macos.sh` and excluded via `.gitignore`. This repo contains
  only macOS build/bundle/packaging scripts and no game source code.
* **Script prefix** — all scripts renamed from bare names (`build-macos.sh`) to
  `smca-` prefix (`smca-build-macos.sh`), matching the `pdmv-` convention.
* **Launcher** — `run-starship.sh` → `run-smca-macos.sh`.
* **New `smca-initial-setup.sh`** — dedicated first-run dependency installer,
  separated from the build script.
* **ROM directory** — ROMs now live in `roms/` (gitignored) instead of the repo
  root. The build script copies the ROM into the upstream clone automatically.
* **Top-level logs/** — all log output moved to `logs/` at the repo root,
  surviving `rm -rf Starship/` during stale-clone recovery.
* **License** — changed from CC0-1.0 to MIT (consistent with perfectdark-macvanta).
* **Versioning reset** — all scripts start at `v0.10` for the restructured repo.

**Scripts ported (all confirmed feature-equivalent to pre-restructure):**

| Old name | New name | Notes |
|---|---|---|
| `build-macos.sh` | `smca-build-macos.sh` | Now clones upstream; inline dep install |
| `bundle-macos.sh` | `smca-bundle-macos.sh` | Unchanged logic, new paths |
| `package-macos.sh` | `smca-package-macos.sh` | Renamed DMG to `smca-macalfa-Intel-Mac` |
| `run-starship.sh` | `run-smca-macos.sh` | All v1.10 features preserved |
| `sysinfo.sh` | `smca-systeminfo.sh` | Adapted paths |
| `collect-crash.sh` | `smca-collect-crash.sh` | Adapted paths |
| `patch-hidpi.sh` | `smca-patch-hidpi.sh` | Searches inside `Starship/` clone |
| *(none)* | `smca-initial-setup.sh` | **New** — first-run setup |

**Migration from old fork:**

1. Clone this new repo: `git clone https://github.com/mkoterski/starship-macalfa.git`
2. Place ROM: `cp /path/to/baserom.us.rev1.z64 roms/`
3. Run: `./smca-initial-setup.sh && ./smca-build-macos.sh && ./run-smca-macos.sh`
4. The old forked repo can be archived or deleted.

---

## [1.0] — 2026-03-05 (pre-restructure)

### Confirmed Working

* SF64 title screen reached on MacBook Pro 2020 Intel i7, macOS Tahoe 26.3.
* OpenGL backend confirmed stable; Metal crashes with `std::bad_variant_access`.
* DMG installer (`package-macos.sh v0.21`) with SF64 space-themed background.
* Retina HiDPI support via `patch-hidpi.sh`.
* Full script suite: build, bundle, package, run, sysinfo, collect-crash.