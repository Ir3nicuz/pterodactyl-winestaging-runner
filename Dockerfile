# syntax=docker/dockerfile:1
# ^^^ This line must be the first in the script to activate the Heredoc-Feature.

# use wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# Initials
ARG ARG_BUILD_NUMBER=-1
ENV ENV_BUILD_NUMBER=${ARG_BUILD_NUMBER}
ENV DISPLAY=:0
ENV WINEARCH=win64
ENV WINEDEBUG=-all
ENV WINEPREFIX=/home/container/.wine

USER root

# SteamCmd and Wings dependencies integration
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
    xvfb \
    libasound2t64 \
    libpulse0 \
    libgl1:i386 \
    libglx-mesa0:i386 \
    libnss3 \
    lib32gcc-s1 \
    lib32stdc++6 \
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
export APP_ID=${STEAMGAME_APPID}

# virtual display init
echo -e "${BLUEINFOTAG} Initializing virtual dummy Display ..."
Xvfb :0 -screen 0 1024x768x16 &
sleep 3
if pgrep -x "Xvfb" > /dev/null; then
    echo -e "${GREENSUCCESSTAG} Virtual dummy Display started successfully!"
else
    echo -e "${YELLOWWARNINGTAG} Virtual dummy Display failed to start. Wine might crash."
fi

# wine init
if [[ ! -d "$WINEPREFIX" ]]; then
    echo -e "${BLUEINFOTAG} Initializing Wine Prefix ..."
    wineboot --init
	echo -e "${GREENSUCCESSTAG} Wine initialization done!"
fi

echo -e "${BLUEINFOTAG} Starting Server with Steam Id ${APP_ID} ..."
exec wine "${STEAMGAME_PATHTOEXE}" ${STEAMGAME_STARTUPPARAMS}

EOF

# launch script execution permission
RUN chmod +x /usr/local/bin/launch

# launch image script context setup
USER container
WORKDIR /home/container
