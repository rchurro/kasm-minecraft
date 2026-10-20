# kasm-minecraft

A [Kasm Workspaces](https://kasmweb.com) image for **Minecraft: Java Edition**, using
[Prism Launcher](https://prismlauncher.org). It launches straight into the launcher (no
desktop), renders on the GPU when Kasm assigns one, and keeps your sign-in and worlds in
Kasm's persistent profile.

```
ghcr.io/rchurro/kasm-minecraft:1.19.0
```

## Install in one click

Add this repo's Kasm registry and the workspace comes pre-configured:

1. In Kasm, go to **Admin → Workspaces → Registry** and click **Add new**.
2. Paste `https://rchurro.github.io/kasm-registry/` and save.
3. Find **Minecraft (Prism Launcher)** in the list and click **Install**.

Then set GPU count 1, EGL and NVENC on the workspace for GPU rendering (details below).
You need a Microsoft account that owns Minecraft: Java Edition; the game downloads on first launch.

- Base: `kasmweb/core-ubuntu-noble:1.19.0`, single-application mode
- Prism Launcher (latest at build time) with OpenJDK 21 and 25; Prism fetches others on demand
- GPU rendering through VirtualGL ≥ 3.1.5 (see below)
- Passwordless `sudo` for `kasm-user`, so you can `apt install` extras in a session
- No Minecraft game files are included. Prism downloads them on first launch, and you
  need a Microsoft account that owns Minecraft: Java Edition.

Versions are pinned in the `Dockerfile` (Kasm base by digest, Prism Launcher, VirtualGL) and
kept current by [Renovate](https://docs.renovatebot.com): it opens a PR or, for patch and
minor updates that build cleanly, merges itself, and every merge publishes a new image.
A monthly rebuild picks up Ubuntu security updates.

## Install

**From the workspace registry:** in Kasm, go to *Admin → Workspaces → Registry → Add new*,
enter `https://rchurro.github.io/kasm-registry/`, then install **Minecraft**.

**Manually:** *Admin → Workspaces → Add Workspace*:

| Field | Value |
|---|---|
| Docker image | `ghcr.io/rchurro/kasm-minecraft:1.19.0` |
| Cores / Memory | 4 / 8192 MB or more |
| GPU count | 1 (optional, strongly recommended) |
| Graphics acceleration | EGL |
| Video encoding | NVENC (NVIDIA) |
| Persistent profile path | e.g. `/mnt/kasm_profiles/{username}/{image_id}` (keeps your login, instances and worlds) |

## GPU notes

Kasm passing a GPU through doesn't make OpenGL use it: apps still render on Mesa's
`llvmpipe` (CPU) unless they run under VirtualGL. This image sets Prism's *wrapper command*
to `mc-gpu`, which runs the game under `vglrun -d $KASM_EGL_CARD` whenever Kasm has
assigned a GPU, and runs it normally otherwise. `custom_startup.sh` re-applies that setting
at every start, because an existing persistent profile keeps its own Prism config.

- **VirtualGL 3.1.5 or newer is required.** Older EGL back ends (Kasm's base ships 3.1.3)
  leave Minecraft Java with a black screen (`GL_INVALID_FRAMEBUFFER_OPERATION`).
- Check the game log for `Using graphics device:`. It should name your GPU, not `llvmpipe`.
- If GPU sessions fail with *"requires a hardware based graphics acceleration stack
  (['EGL']) but no supporting hardware found"*, your Kasm agent can't see CUDA. On Docker
  installs, give the `kasm_agent` service `runtime: nvidia` with
  `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=all`.
- First-person mouse look works best with KasmVNC's *Game Pointer Mode* and a lower
  in-game sensitivity.

## Build

```bash
docker build -t kasm-minecraft .
```

Build args: `PRISM_VERSION`, `VGL_VERSION`, `JAVA_PATH`.

### Private variant with pre-baked game files

```bash
docker build -f Dockerfile.baked -t kasm-minecraft-baked .
```

`Dockerfile.baked` starts from the public image and runs `bake.py`, which downloads a
Minecraft release's client, libraries and assets (`--build-arg MC_VERSION=<version>`,
default `latest`) into Prism's layout, seeds Prism's download cache and creates a ready
instance. Sessions then start without Prism's several-minute first download.

**A baked image contains Mojang's game files, which may not be redistributed.** Build it
yourself and load it straight into your own Kasm; never push it to a public registry.
