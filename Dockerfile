# Use pterodactyl wine yolk as base - proven to work with Starrupture
FROM ghcr.io/ptero-eggs/yolks:wine_latest

LABEL maintainer="loganintech"
LABEL description="Starrupture Dedicated Server"

# Install tini for signal handling
RUN apt-get update && apt-get install -y \
    tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The base image uses /home/container as HOME (runs as root)
WORKDIR /home/container

# Create directories for server files and saves
RUN mkdir -p /home/container/starrupture \
             /home/container/starrupture/server_files \
             /home/container/starrupture/saves \
             /home/container/starrupture/config \
             /home/container/steamcmd

# Install SteamCMD
RUN cd /home/container/steamcmd && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -

# Wine configuration (inherit from base)
ENV WINEPREFIX=/home/container/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=fixme-all

# Initialize Wine prefix if not already done
RUN wineboot --init && wineserver --wait || true

# Environment variables for configuration
ENV STEAM_APP_ID=3809400
ENV SERVER_PORT=7777
ENV QUERY_PORT=27015
ENV MULTIHOME=0.0.0.0
ENV UPDATE_ON_START=true
ENV VALIDATE_ON_START=false
ENV ADDITIONAL_ARGS=""
# DSSettings configuration (creates DSSettings.txt for auto-start)
ENV SESSION_NAME=""
ENV SAVE_GAME_NAME=""
ENV SAVE_GAME_INTERVAL=300
ENV START_NEW_GAME=false
ENV LOAD_SAVED_GAME=true

# Copy entrypoint script
COPY entrypoint.sh /home/container/entrypoint.sh
RUN chmod +x /home/container/entrypoint.sh

# Expose ports (UDP + TCP for game, UDP for query)
EXPOSE 7777/udp
EXPOSE 7777/tcp
EXPOSE 27015/udp

# Volumes for persistence
VOLUME ["/home/container/starrupture"]

# Use tini as init system for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/home/container/entrypoint.sh"]
