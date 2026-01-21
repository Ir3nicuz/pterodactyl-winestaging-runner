# syntax=docker/dockerfile:1
# ^^^ This line must be the first in the script to activate the Heredoc-Feature.

# use wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# Initials
ARG ARG_BUILD_NUMBER=-1
ENV ENV_BUILD_NUMBER=${ARG_BUILD_NUMBER}
ENV WINEARCH=win64
ENV WINEDEBUG=+err,+module
ENV WINEPREFIX=/home/container/.wine
ENV WINEDLLOVERRIDES="mscoree,mshtml=d"

USER root

# SteamCmd and Wings dependencies integration
RUN dpkg --add-architecture i386 \
    && sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list || true \
    && apt-get update && apt-get install -y --no-install-recommends \
    xvfb \
    libxrender1 libxinerama1 libxi6:i386 libxrandr2:i386 \
    libasound2 libpulse0 libnss3 \
    lib32gcc-s1 lib32stdc++6 libgl1:i386 libglx-mesa0:i386 \
    libxcomposite1 libxcursor1 libxi6 libxrandr2 libxtst6 \
    zenity cabextract \
    && wget -q -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Here-Doc definition of launch script as launch
RUN <<'EOF' cat > /usr/local/bin/launch
#!/bin/bash

# Text marker colors
REDERRORTAG='\e[31m[ERROR]\e[0m'
GREENSUCCESSTAG='\e[32m[SUCCESS]\e[0m'
YELLOWWARNINGTAG='\e[33m[WARNING]\e[0m'
BLUEINFOTAG='\e[34m[INFO]\e[0m'

# startup
sleep 1
echo -e "${BLUEINFOTAG} Starting launch script (Build-Rev: ${ENV_BUILD_NUMBER}) ..."

# --- Validation ---
if [[ -z "${STEAMGAME_APPID}" ]]; then
    echo -e "${REDERRORTAG} Variable STEAMGAME_APPID not set!"
    exit 1
fi
if ! [[ "${STEAMGAME_APPID}" =~ ^[0-9]+$ ]]; then
    echo -e "${REDERRORTAG} Variable STEAMGAME_APPID '${STEAMGAME_APPID}' is not a valid id!"
    exit 1
fi
if [[ -z "${STEAMGAME_PATHTOEXE}" ]]; then
    echo -e "${REDERRORTAG} Variable STEAMGAME_PATHTOEXE not set!"
    exit 1
fi
if [[ -z "${STEAMGAME_STARTUPPARAMS}" ]]; then
    echo -e "${REDERRORTAG} Variable STEAMGAME_STARTUPPARAMS not set!"
    exit 1
fi
echo -e "${GREENSUCCESSTAG} Variables validation done!"

# --- Launch ---
# wine init
export SRCDS_APPID=${STEAMGAME_APPID}
if [[ ! -f "$WINEPREFIX/vcredist_installed.flag" ]]; then
    echo -e "${BLUEINFOTAG} Initializing Wine with Windows components ..."
	
    rm -rf "$WINEPREFIX"
    xvfb-run --auto-servernum --server-args="-screen 0 1024x768x16 -nolisten unix" bash -c "
        wineboot --init && \
        wineserver -w && \
        winetricks -q vcrun2022 && \
        wineserver -w
    "
	
    touch "$WINEPREFIX/vcredist_installed.flag"
    echo -e "${GREENSUCCESSTAG} Wine and VC++ initialization done!"

	wineserver -k
	sleep 3
fi

# server start with virtual graphics dummy xvfb
echo -e "${BLUEINFOTAG} Starting Server with Steam Id ${STEAMGAME_APPID} ..."
exec xvfb-run -a --auto-servernum --server-args="-screen 0 1024x768x16 -nolisten unix" \
    wine "${STEAMGAME_PATHTOEXE}" ${STEAMGAME_STARTUPPARAMS} 2>&1 | grep "err:"

EOF

# script execution permissions
RUN chmod +x /usr/local/bin/launch
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# launch image script context setup
USER container
WORKDIR /home/container
