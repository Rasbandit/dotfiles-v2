---
name: unraid-docker
description: >
  How to manage Docker containers on Unraid servers. MUST trigger whenever creating, modifying,
  deploying, or configuring Docker containers on FastRaid (10.0.20.214) or SlowRaid (10.0.20.201).
  Trigger on: "add a container to Unraid", "deploy to FastRaid/SlowRaid", "create a docker container",
  "set up a new service on Unraid", any docker run/compose discussion targeting Unraid hosts,
  or any task that involves writing Dockerfiles or docker-compose.yml for Unraid servers.
  DO NOT trigger for: Claw (local Fedora machine) Docker work, or general Docker questions
  not targeting Unraid.
---

# Unraid Docker Container Management

**You are working on an Unraid server. Unraid has its own container management system. Do NOT use docker-compose, Dockerfiles, or raw `docker run` commands to create persistent containers.**

## The #1 Rule

**Unraid containers are defined by XML templates, not docker-compose.yml files.**

Every container is managed through an XML template on the USB boot drive:
```
/boot/config/plugins/dockerMan/templates-user/my-<ContainerName>.xml
```

The Unraid web UI reads these XMLs. When you click "Apply", Unraid translates the XML into a `docker run` command. This is how ALL persistent containers must be defined.

### Why NOT docker-compose

- Compose containers don't appear in the Unraid Docker UI — no start/stop/update buttons, no icon
- NOT included in Unraid's appdata backup plugin
- NOT stopped/started during maintenance windows
- Bypass auto-start ordering and update mechanisms

**No exceptions.** Always create individual XML templates, even for multi-container stacks. Each container gets its own template, connected via a shared Docker network for inter-service communication.

## Creating a New Container

### Step 1: Write the XML template

Create `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml` via SSH. See `references/xml-reference.md` for the full XML structure and element reference.

Minimal template:

```xml
<?xml version="1.0"?>
<Container version="2">
  <Name>my-service</Name>
  <Repository>image/name:latest</Repository>
  <Network>bridge</Network>
  <Shell>bash</Shell>
  <Privileged>false</Privileged>
  <Overview>What this container does</Overview>

  <Config Name="AppData" Target="/config" Default="/mnt/user/appdata/my-service"
          Mode="rw" Type="Path" Display="always" Required="true" Mask="false">/mnt/cache/appdata/my-service</Config>

  <Config Name="Web Port" Target="8080" Default="8080"
          Mode="tcp" Type="Port" Display="always" Required="false" Mask="false">8080</Config>
</Container>
```

### Step 2: Create the appdata directory

```bash
ssh root@<host> 'mkdir -p /mnt/cache/appdata/<name>'
```

### Step 3: Start the container

**Option A — Translate XML to `docker run` and execute via SSH:**

The XML maps to `docker run` flags like this:

| XML Element | docker run flag |
|-------------|----------------|
| `<Name>` | `--name=<value>` |
| `<Repository>` | image (last argument) |
| `<Network>` | `--network=<value>` |
| `<ExtraParams>` | raw flags (e.g. `--gpus=all`) |
| `<Privileged>true</Privileged>` | `--privileged` |
| `<Config Type="Path">` | `-v <text>:<Target>:<Mode>` |
| `<Config Type="Port">` | `-p <text>:<Target>/<Mode>` |
| `<Config Type="Variable">` | `-e <Target>=<text>` |

Example translation:

```bash
ssh root@<host> 'docker run -d \
  --name=my-service \
  --network=bridge \
  -v /mnt/cache/appdata/my-service:/config:rw \
  -p 8080:8080/tcp \
  image/name:latest'
```

**Option B — Use the Unraid Web UI:** The container appears as a new entry in the Docker tab. Click it → Apply.

### Step 4: Verify

```bash
ssh root@<host> 'docker ps --filter name=my-service --format "{{.Names}} {{.Status}}"'
```

## Modifying an Existing Container

1. **Edit the XML** at `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml`
2. **Tell the user to Apply from the Unraid GUI** — Docker tab → click the container → Edit → Apply

**⚠️ NEVER use `docker rm` + `docker run` to recreate a container.** DockerMan only tracks containers it creates through the web UI. A CLI-created container shows as "3rd party" in the Docker tab — no edit button, no template association, no GUI control. There is no CLI workaround; DockerMan registration only happens through the web UI "Apply" action.

**What you CAN do from CLI:**
- `docker start/stop/restart <name>` — safe, doesn't break tracking
- Edit XML templates via SSH — safe, changes take effect on next "Apply"
- Edit container config files on the bind mount (e.g., Plex Preferences.xml) — safe

**What you MUST NOT do from CLI:**
- `docker rm` + `docker run` — breaks DockerMan tracking
- `docker create` — same problem
- Any operation that destroys and recreates the container

If you modify the running container via `docker run` without updating the XML, the UI and runtime will be out of sync. The next "Apply" from the UI overwrites runtime with XML. **Always update the XML for persistent changes.**

## Quick Reference

### Appdata Paths

| Path | Use |
|------|-----|
| `/mnt/cache/appdata/<container>/` | **Always use this** — direct cache SSD, fast |
| `/mnt/user/appdata/<container>/` | FUSE union mount — slower, avoid in volume mounts |

### Docker Networks

| Type | When to use | XML |
|------|-------------|-----|
| Custom bridge (`ai`, `immich`, etc.) | Related containers that need DNS resolution by name | `<Network>ai</Network>` |
| `macvlan` (`br0`) | Container needs its own LAN IP | `<Network>br0</Network>` |
| `bridge` | Default, isolated | `<Network>bridge</Network>` |
| `host` | Shares host network stack | `<Network>host</Network>` |

### GPU Passthrough

Requires **Nvidia-Driver** plugin. Add to XML: `<ExtraParams>--gpus=all</ExtraParams>`

Check status: `ssh root@<host> nvidia-smi`

### Runtime

- Docker 27.5.1 (not Podman), managed by `/etc/rc.d/rc.docker` (not systemd)
- Unraid 7.2.3 on both FastRaid and SlowRaid
- Image storage: loopback `.img` on cache drive (FastRaid 100 GB, SlowRaid 50 GB)

## Gotchas

- **XML `<Config>` values must be inline** — No whitespace between the tag and the value. `<Config ...>value</Config>`, NOT `<Config ...>\n    value\n  </Config>`. Whitespace is included in the value and shows up in the Unraid GUI as padding around every field.
- **`/boot` is vfat** — `chmod +x` silently fails. Scripts must live on `/mnt/cache/appdata/scripts/`.
- **Container names are case-sensitive** — `Huntarr` ≠ `huntarr`. Check the XML `<Name>` element.
- **XML is the source of truth** — if someone ran `docker run` without updating the XML, the UI and runtime are out of sync. Next "Apply" from UI overwrites with XML.
- **Appdata backup stops containers** — the CA Appdata Backup plugin stops containers during backup, then restarts them. Expected during maintenance windows.
- **Image updates** — Unraid's Docker tab shows updates. "Update" pulls new image and recreates from same XML. No data loss (appdata on separate volume).
- **Loopback `.img` full** — containers can't start. `docker system prune -f` or resize in Settings → Docker.
- **NEVER `docker rm` + `docker run`** — This creates a "3rd party" container that DockerMan can't control. The user loses GUI management (no edit/update buttons). The only fix is to remove the container and re-apply the template through the Unraid web UI. Use `docker start/stop/restart` for runtime control; edit the XML + tell user to Apply for config changes.

## Reference

For full XML element docs, injected labels/env vars, config file locations, and CLI commands, see `references/xml-reference.md`.
