# Use pterodactyl wine yolk as base - proven to work with Starrupture
FROM ghcr.io/ptero-eggs/yolks:wine_latest

LABEL maintainer="loganintech"
LABEL description="Starrupture Dedicated Server"

# Switch to root for setup
USER root

# Install SteamCMD dependencies and tini
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    lib32gcc-s1 \
    tini \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create steam user (don't run as root)
RUN useradd -m -s /bin/bash steam
WORKDIR /home/steam

# Install SteamCMD
RUN mkdir -p /home/steam/steamcmd && \
    cd /home/steam/steamcmd && \
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf - && \
    chown -R steam:steam /home/steam

# Create directories for server files and saves
RUN mkdir -p /home/steam/starrupture \
             /home/steam/starrupture/saves \
             /home/steam/starrupture/config && \
    chown -R steam:steam /home/steam/starrupture

# Switch to steam user
USER steam

# Wine configuration (inherit from base, but set our prefix)
ENV WINEPREFIX=/home/steam/.wine
ENV WINEARCH=win64
ENV WINEDEBUG=fixme-all

# Initialize Wine prefix
RUN wineboot --init && wineserver --wait

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
COPY --chown=steam:steam entrypoint.sh /home/steam/entrypoint.sh
RUN chmod +x /home/steam/entrypoint.sh

# Expose ports (UDP + TCP for game, UDP for query)
EXPOSE 7777/udp
EXPOSE 7777/tcp
EXPOSE 27015/udp

# Volumes for persistence
VOLUME ["/home/steam/starrupture"]

# Use tini as init system for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/home/steam/entrypoint.sh"]
