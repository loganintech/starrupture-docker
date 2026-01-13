FROM debian:bookworm-slim

LABEL maintainer="loganintech"
LABEL description="Starrupture Dedicated Server"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# SteamCMD and Wine architecture
RUN dpkg --add-architecture i386

# Install dependencies
RUN apt-get update && apt-get install -y \
    # Base utilities
    ca-certificates \
    curl \
    wget \
    locales \
    lib32gcc-s1 \
    # Wine dependencies
    wine \
    wine32 \
    wine64 \
    xvfb \
    # Process management
    tini \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set up locale
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

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

# Initialize Wine prefix (do this during build to speed up first run)
ENV WINEPREFIX=/home/steam/.wine
ENV WINEARCH=win64
# Set to -all to suppress Wine debug output, or leave empty for debug info
ENV WINEDEBUG=fixme-all
RUN wineboot --init && \
    wineserver --wait

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
