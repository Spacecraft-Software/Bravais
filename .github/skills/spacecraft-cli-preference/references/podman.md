# podman

**Replaces:** `docker` | **Language:** 🐹 Go | **Install:** distro repo

## Purpose
Daemonless, rootless, Docker-CLI-compatible container engine. Runs OCI containers/pods without a privileged daemon. Spacecraft Software-sanctioned for container workflows.

## Key commands (Docker-compat)
| Command | Meaning |
|---------|---------|
| `podman pull IMAGE` | Fetch image |
| `podman run [-it] IMAGE CMD` | Run container |
| `podman ps [-a]` | List containers |
| `podman images` | List images |
| `podman build -t NAME .` | Build from Containerfile/Dockerfile |
| `podman exec -it CTR CMD` | Shell into running container |
| `podman logs CTR` | View logs |
| `podman rm CTR` / `podman rmi IMAGE` | Delete |
| `podman pod create --name POD` | Pods (multiple containers, shared netns) |
| `podman generate systemd` | Emit systemd unit for a container |
| `podman compose up` | Docker-compose-compatible (needs plugin or `podman-compose`) |

## Examples
1. Run an Alpine shell: `podman run --rm -it docker.io/alpine sh`
2. Build image: `podman build -t spacecraft-software/ferrocast:dev .`
3. Detached with port mapping: `podman run -d -p 8080:80 nginx:alpine`
4. Generate a user systemd unit: `podman generate systemd --new --files --name myctr`
5. Rootless volume mount: `podman run -v "$PWD":/app:Z image`

## Gotchas
- Rootless networking uses `slirp4netns`/`pasta` — slightly different perf/port binding than rootful Docker.
- SELinux systems need `:z` (shared) or `:Z` (private) volume labels.
- `alias docker=podman` works for most scripts, but `docker.sock` clients need `podman system service`.
