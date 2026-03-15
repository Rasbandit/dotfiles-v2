# Unraid Docker XML Template Reference

## Full XML Template Example

```xml
<?xml version="1.0"?>
<Container version="2">
  <Name>ollama</Name>
  <Repository>ollama/ollama</Repository>
  <Registry>https://hub.docker.com/r/ollama/ollama/</Registry>
  <Network>ai</Network>
  <MyIP/>
  <Shell>bash</Shell>
  <Privileged>false</Privileged>
  <Overview>Description shown in Unraid UI</Overview>
  <WebUI>http://[IP]:[PORT:11434]/</WebUI>
  <Icon>https://ollama.ai/public/ollama.png</Icon>
  <ExtraParams>--gpus=all</ExtraParams>
  <CPUset/>

  <!-- Volume mount -->
  <Config Name="Config" Target="/root/.ollama" Default="/mnt/user/appdata/ollama"
          Mode="rw" Type="Path" Display="always" Required="false" Mask="false">
    /mnt/cache/appdata/ollama
  </Config>

  <!-- Port mapping -->
  <Config Name="Web Interface" Target="11434" Default="11434"
          Mode="tcp" Type="Port" Display="always" Required="false" Mask="false">
    11434
  </Config>

  <!-- Environment variable -->
  <Config Name="OLLAMA_ORIGINS" Target="OLLAMA_ORIGINS" Default=""
          Mode="" Type="Variable" Display="always" Required="false" Mask="false">
    *
  </Config>
</Container>
```

## XML Elements

| Element | Purpose |
|---------|---------|
| `<Name>` | Container name (case-sensitive, used by `docker start/stop`) |
| `<Repository>` | Docker image (e.g. `ollama/ollama`, `lscr.io/linuxserver/sonarr`) |
| `<Registry>` | Docker Hub URL for the image (informational, shown in UI) |
| `<Network>` | Docker network to join (e.g. `ai`, `bridge`, `br0`) |
| `<MyIP>` | Static IP when using macvlan (empty for bridge networks) |
| `<Shell>` | Default shell for console access (`bash` or `sh`) |
| `<Privileged>` | Whether container runs privileged (`true`/`false`) |
| `<CPUset>` | CPU pinning (empty = all CPUs, e.g. `0,1,2,3` for specific cores) |
| `<Overview>` | Description shown in Unraid UI |
| `<WebUI>` | URL template for dashboard link. `[IP]` and `[PORT:n]` are placeholders |
| `<Icon>` | URL to container icon shown in UI |
| `<ExtraParams>` | Raw flags passed to `docker run` (e.g. `--gpus=all`, `--cap-add=NET_ADMIN`) |
| `<PostArgs>` | Arguments appended after the image name in `docker run` |

### Config Elements

The `<Config>` element handles volume mounts, port mappings, and environment variables. The `Type` attribute determines which:

| Type | Element text | `Target` attr | `Mode` attr |
|------|-------------|---------------|-------------|
| `Path` | Host path | Container path | `rw` or `ro` |
| `Port` | Host port | Container port | `tcp` or `udp` |
| `Variable` | Value | Variable name | (unused) |

**Other Config attributes:**

| Attribute | Purpose |
|-----------|---------|
| `Name` | Human-readable label shown in UI |
| `Default` | Default value (pre-filled for Community Apps templates) |
| `Display` | `always`, `advanced`, or `hidden` — controls visibility in UI |
| `Required` | `true`/`false` — whether the field must be filled |
| `Mask` | `true`/`false` — hides value in UI (for secrets/passwords) |

## Unraid-Injected Labels and Env Vars

Unraid automatically adds to every container:

**Environment variables:**
- `TZ` — timezone from Unraid settings
- `HOST_OS=Unraid`
- `HOST_HOSTNAME=<server-name>`
- `HOST_CONTAINERNAME=<container-name>`

**Labels:**
- `net.unraid.docker.managed=dockerman`
- `net.unraid.docker.icon=<icon-url>`
- `net.unraid.docker.webui=<webui-url>`

## Key Config Files

| File | Location | Purpose |
|------|----------|---------|
| `docker.cfg` | `/boot/config/docker.cfg` | Docker daemon settings (image file, appdata path, networks, log rotation) |
| `daemon.json` | `/etc/docker/daemon.json` | Runtime config (GPU runtime registration) |
| XML templates | `/boot/config/plugins/dockerMan/templates-user/my-*.xml` | Per-container definitions |
| Compose files | `/boot/config/docker-compose/<project>/docker-compose.yml` | Compose stacks (use sparingly) |

## Common CLI Operations

```bash
# List all XML templates
ssh root@<host> 'ls /boot/config/plugins/dockerMan/templates-user/'

# View a container's XML definition
ssh root@<host> 'cat /boot/config/plugins/dockerMan/templates-user/my-<Name>.xml'

# Compare running state vs XML
ssh root@<host> 'docker inspect <Name> --format="{{json .Config}}"' | jq

# Check Docker daemon config
ssh root@<host> 'cat /boot/config/docker.cfg'

# Docker disk usage
ssh root@<host> 'docker system df'

# Prune unused images/layers
ssh root@<host> 'docker system prune -f'

# Check Docker image file size
ssh root@<host> 'ls -lh /mnt/cache/system/docker/docker.img'
```
