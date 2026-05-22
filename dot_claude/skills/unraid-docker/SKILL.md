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

Two approaches: **GUI Apply** (simplest) and **CLI Recreation** (for autonomous/non-interactive sessions).

### Option A: GUI Apply (when a human is available)

1. **Edit the XML** at `/boot/config/plugins/dockerMan/templates-user/my-<Name>.xml`
2. **Tell the user to Apply from the Unraid GUI** — Docker tab → click the container → Edit → Apply

### Option B: CLI Recreation (autonomous — no GUI needed)

When running non-interactively (e.g., triage agent, automated deployment), you can recreate containers entirely from CLI. The key is the `net.unraid.docker.managed=dockerman` label — this is how DockerMan identifies its containers.

**The full CLI recreation sequence:**

```bash
# 1. BACKUP the XML template (safety net)
ssh root@<host> 'cp /boot/config/plugins/dockerMan/templates-user/my-<Name>.xml \
  /boot/config/plugins/dockerMan/templates-user/my-<Name>.xml.bak'

# 2. UPDATE the XML template FIRST (so UI stays in sync)
#    Edit via SSH, heredoc, or sftp — update <Repository>, <Config>, etc.

# 3. PULL the new image (if changing images)
ssh root@<host> 'docker pull <new-image>'

# 4. STOP the running container
ssh root@<host> 'docker stop <Name>'

# 5. REMOVE the old container (data volumes are untouched)
ssh root@<host> 'docker rm <Name>'

# 6. CREATE the new container — MUST include the dockerman label
ssh root@<host> 'docker create \
  --name=<Name> \
  --net=<Network> \
  --restart=unless-stopped \
  -v /mnt/cache/appdata/<name>:/config:rw \
  -e KEY=value \
  -l net.unraid.docker.managed=dockerman \
  <image>'

# 7. START
ssh root@<host> 'docker start <Name>'

# 8. VERIFY — container health + DockerMan tracking
ssh root@<host> 'docker ps --filter name=<Name> --format "{{.Names}} {{.Status}}"'
ssh root@<host> 'docker inspect <Name> --format "managed={{index .Config.Labels \"net.unraid.docker.managed\"}}"'
```

**Why this works:** DockerMan identifies managed containers by the `net.unraid.docker.managed=dockerman` label and matches them to XML templates by container name (`my-<Name>.xml`). When both the label and the XML template exist and the names match, the Unraid Docker tab shows the container as fully managed — Edit button, update detection, and all GUI controls work normally.

### CLI Recreation — Critical Rules

| Rule | Why |
|------|-----|
| **Update the XML BEFORE recreating** | The XML is the source of truth. If it doesn't match the running container, the next GUI "Apply" will overwrite your changes |
| **ALWAYS add `-l net.unraid.docker.managed=dockerman`** | Without this label, the container shows as "3rd party" — no Edit button, no GUI control |
| **Match the container name exactly** | DockerMan links containers to templates by name. `<Name>` in XML must match `--name=` in `docker create`. Case-sensitive |
| **Translate ALL XML `<Config>` elements** | Every `<Config Type="Path">` → `-v`, every `<Config Type="Port">` → `-p`, every `<Config Type="Variable">` → `-e`. Missing one means data loss or broken config |
| **Include `<ExtraParams>` flags** | These are raw `docker run` flags (e.g., `--gpus=all`, `--cap-add=NET_ADMIN`). Forgetting them breaks GPU/network/privilege config |
| **Backup the XML first** | If the recreation fails, you can restore the XML and recreate from the old image |

### XML → docker create Translation Table

| XML Element | docker create flag | Example |
|-------------|-------------------|---------|
| `<Name>` | `--name=<value>` | `--name=firecrawl-postgres` |
| `<Repository>` | image (last argument) | `qonicsinc/postgres-pgcron:latest` |
| `<Network>` | `--net=<value>` | `--net=ai` |
| `<ExtraParams>` | raw flags (verbatim) | `--gpus=all --restart=unless-stopped` |
| `<Privileged>true` | `--privileged` | |
| `<Config Type="Path">` | `-v <text>:<Target>:<Mode>` | `-v /mnt/cache/appdata/x:/data:rw` |
| `<Config Type="Port">` | `-p <text>:<Target>/<Mode>` | `-p 8080:8080/tcp` |
| `<Config Type="Variable">` | `-e <Target>=<text>` | `-e POSTGRES_USER=firecrawl` |
| (always add) | `-l net.unraid.docker.managed=dockerman` | required for DockerMan tracking |

### What you CAN do from CLI (safe operations)

- `docker start/stop/restart <name>` — doesn't break tracking
- Edit XML templates via SSH — changes take effect on next Apply or CLI recreation
- Edit container config files on bind mounts (e.g., Plex Preferences.xml)
- Full `docker stop` → `docker rm` → `docker create` → `docker start` cycle **with the dockerman label**

### What you MUST NOT do

- `docker create` or `docker run` **without** the `-l net.unraid.docker.managed=dockerman` label — creates a "3rd party" container
- Recreate a container **without** updating the XML template first — causes UI/runtime desync
- Use `docker-compose` — see "Why NOT docker-compose" above

If the XML and running container are out of sync, the next GUI "Apply" overwrites runtime with XML. **Always update the XML for persistent changes.**

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
- **`docker rm` + `docker create` requires the dockerman label** — If you recreate a container without `-l net.unraid.docker.managed=dockerman`, it shows as "3rd party" and loses GUI control. Always include the label. See "Modifying an Existing Container → Option B" for the full CLI recreation workflow.

## Reference

For full XML element docs, injected labels/env vars, config file locations, and CLI commands, see `references/xml-reference.md`.
