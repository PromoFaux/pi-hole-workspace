# Pi-hole Development Workspace

## Purpose

This workspace exists to give the developer a flexible, self-contained environment for building and testing the `docker-pi-hole` image on Windows. Having all Pi-hole component repositories present locally means changes to any component (e.g. FTL, web, pi-hole scripts) can be tested immediately in Docker without waiting for upstream GitHub releases.

## Repository Structure

This is a workspace repository. The sub-repositories below are cloned into the workspace root by `init-workspace.ps1` and are **not** independently managed by separate CLAUDE.md files — this file governs all of them.

| Directory | Upstream | Description |
|---|---|---|
| `FTL/` | `pi-hole/FTL` | DNS engine (C/C++, CMake) |
| `pi-hole/` | `pi-hole/pi-hole` | Core scripts (bash, gravity, installer) |
| `web/` | `pi-hole/web` | Web admin interface (Lua templates, Tailwind CSS) |
| `web-vue/` | — | New Vue.js web interface (in progress, untracked) |
| `docker-pi-hole/` | `pi-hole/docker-pi-hole` | Docker container definition |
| `PADD/` | `pi-hole/PADD` | Pi-hole stats display |
| `docs/` | `pi-hole/docs` | Documentation |
| `docker-base-images/` | `pi-hole/docker-base-images` | Base Docker images |
| `.github/` | `pi-hole/.github` | Organization-level GitHub metadata (workflows, templates, issue templates) |
| `docker-manual-testing/` | — | Local Docker Compose test environment |

## Build Scripts

All build/run scripts are PowerShell (`.ps1`) and live in the workspace root. They must be run from the workspace root.

| Script | Purpose |
|---|---|
| `init-workspace.ps1` | Clone all sub-repos and check out `development` branch |
| `build-ftl.ps1` | Build FTL binary using the official FTL build container |
| `build-docker.ps1` | Build the `docker-pi-hole` Docker image |
| `build-docker.ps1 -BuildFTL` | Build FTL first, then build Docker image (combined workflow) |
| `build-docker.ps1 -l` | Build Docker image using an already-built local FTL binary |
| `run-docker.ps1` | Start the test container via docker-compose |
| `run-docker.ps1 -Detach` | Start containers in background |
| `run-docker.ps1 -Stop` | Stop and remove containers |
| `run-docker.ps1 -Logs` | Follow container logs |
| `build-docs.ps1` | Build documentation |
| `populate-querylog.ps1` | Populate query logs for testing |

### Typical Workflows

- **Test docker-pi-hole with upstream FTL:** `.\build-docker.ps1` then `.\run-docker.ps1`
- **Test with local FTL changes:** `.\build-docker.ps1 -BuildFTL` then `.\run-docker.ps1`
- **Iterate on FTL only:** `.\build-ftl.ps1` then `.\build-docker.ps1 -l` then `.\run-docker.ps1`

## Hard Rules — Never Violate

### GitHub Push Policy
- **Workspace repo** (`pi-hole-workspace`) — this repo uses `master` as its only branch. Pushing to GitHub is permitted here.
- **All sub-repos** (`FTL/`, `pi-hole/`, `web/`, `docker-pi-hole/`, etc.) — **never `git push` without explicit instruction from the developer.**

### Never Use `init-workspace.ps1 -Force`
The `-Force` flag resets all sub-repos and **discards all local changes**. Never invoke it. If workspace re-initialization is needed, run `init-workspace.ps1` without flags and discuss with the developer first.

## General Guidelines

- Changes may span multiple sub-repos (e.g. an FTL change paired with a docker-pi-hole change). Consider cross-repo impact when making modifications.
- The `development` branch is the default working branch across all sub-repos.
- Docker is required for all build and test operations — builds run inside containers, not on the host.
- FTL is built for `linux/amd64` via Docker even on Windows (handled automatically by `build-ftl.ps1`).
- The `docker-manual-testing/` directory contains the `docker-compose.yml` used for local testing. The web interface is available at `http://localhost` when the container is running.
- **Testing with custom volumes:** When mounting additional volumes for testing (e.g., `etc-pihole-phase1test/`), follow the naming pattern `docker-manual-testing/etc-pihole*`. These directories are ignored by `.gitignore` and won't be committed. Update `docker-compose.yml` to mount your test volume, run tests, then clean up the directory when done.
- When working with sub-repos, any new branch should be based on the `development` branch of that sub-repo.

## Pi-hole Contribution Guidelines

These apply when making changes intended for upstream contribution to any Pi-hole sub-repo.

- **Stability before features** — the Pi-hole project prioritises stability. Avoid suggesting speculative or feature-creep changes; focus on correctness and reliability.
- **Branch targeting** — pull requests must target the `development` branch. Always ensure the `development` branch is merged into your working branch and conflicts resolved before a PR is ready.
- **Line endings** — use Unix line endings (LF) in all commits across all sub-repos.
- **Branding** — the correct spelling is **Pi-hole** (capital P, lowercase h, hyphen). Use this consistently in any generated text, commit messages, or documentation.
- **DCO sign-off** — all commits across this workspace (including the workspace repo itself) must be signed off. Always use `git commit -s` (which appends `Signed-off-by: Name <email>`).
