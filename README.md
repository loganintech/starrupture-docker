# Starrupture Dedicated Server

A Docker container for running the Starrupture Dedicated Server.

## Features

- Automatic server installation via SteamCMD
- Windows server running via Wine
- Configurable via environment variables
- Graceful shutdown handling
- Persistent storage for server files and saves
- Proper signal handling with tini

## Quick Start

```bash
docker build -t starrupture-server .
docker run -d \
  --name starrupture \
  -p 7777:7777/udp \
  -p 7777:7777/tcp \
  -p 27015:27015/udp \
  -v starrupture-data:/home/steam/starrupture \
  starrupture-server
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SERVER_PORT` | `7777` | Port for game connections (UDP + TCP) |
| `QUERY_PORT` | `27015` | Steam query port for server browser (UDP) |
| `MULTIHOME` | `0.0.0.0` | Network interface to bind to |
| `UPDATE_ON_START` | `true` | Update server files on container start |
| `VALIDATE_ON_START` | `false` | Validate all files via SteamCMD (slower but thorough) |
| `ADDITIONAL_ARGS` | `` | Additional command-line arguments for the server |

### DSSettings (Auto-Start Configuration)

Set `SESSION_NAME` to enable DSSettings.txt generation for automatic server startup:

| Variable | Default | Description |
|----------|---------|-------------|
| `SESSION_NAME` | `` | Server session name (enables DSSettings if set) |
| `SAVE_GAME_NAME` | `` | Save file to load (e.g., `AutoSave0.sav`) |
| `SAVE_GAME_INTERVAL` | `300` | Auto-save interval in seconds |
| `START_NEW_GAME` | `false` | Start a new game instead of loading |
| `LOAD_SAVED_GAME` | `true` | Load an existing save game |

## Volumes

| Path | Description |
|------|-------------|
| `/home/steam/starrupture` | Server files, saves, and configuration |

### Volume Structure

```
/home/steam/starrupture/
├── server_files/    # Dedicated server installation
├── saves/           # Game save files
└── config/          # Server configuration
```

## Docker Compose

```yaml
version: '3.8'
services:
  starrupture:
    build: .
    container_name: starrupture
    restart: unless-stopped
    ports:
      - "7777:7777/udp"
      - "7777:7777/tcp"
      - "27015:27015/udp"
    volumes:
      - starrupture-data:/home/steam/starrupture
    environment:
      - SERVER_PORT=7777
      - QUERY_PORT=27015
      - MULTIHOME=0.0.0.0
      - UPDATE_ON_START=true
      - VALIDATE_ON_START=false

volumes:
  starrupture-data:
```

## Building

```bash
docker build -t starrupture-server .
```

## Logs

```bash
docker logs -f starrupture
```

## Stopping

The container handles SIGTERM gracefully:

```bash
docker stop starrupture
```

## Troubleshooting

### SteamCMD fails with "Missing configuration"

This usually means the Windows depot isn't available. Try:

1. Clear the server files: `docker volume rm starrupture-data`
2. Restart the container

### Server won't start

Check the logs for the actual error:

```bash
docker logs starrupture
```

The container will list the contents of the server directory if it can't find the executable.

## License

MIT
