# syntax=docker/dockerfile:1
# ^^^ This line must be the first in the script to activate the Heredoc-Feature.

# Use as basic image
FROM ghcr.io/parkervcp/yolks:wine_latest

# Initials
ARG ARG_BUILD_NUMBER=-1
ENV ENV_BUILD_NUMBER=${ARG_BUILD_NUMBER}
ENV WINEDEBUG=fixme-all,warn-all,info-all,+err
ENV WINEARCH=win64
ENV WINEDLLOVERRIDES="mscoree,mshtml=d;winealsa.drv=d;wineoss.drv=d;winemmsystem.drv=d;mmdevapi=d;d3d11=d;d3d9=d;dxgi=d"
USER root

# Tools and Helper integration
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps cabextract wget xvfb xauth \
    wine-mono wine-gecko \
    && wget -q -O /usr/local/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod +x /usr/local/bin/winetricks \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Here-Doc definition of launch script
RUN <<'EOF' cat > /usr/local/bin/launch
#!/bin/bash

# Text marker colors
REDERRORTAG='\e[31m[ERROR]\e[0m'
GREENSUCCESSTAG='\e[32m[SUCCESS]\e[0m'
YELLOWWARNINGTAG='\e[33m[WARNING]\e[0m'
BLUEINFOTAG='\e[34m[INFO]\e[0m'

# --- Startup ---
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
if [[ -z "${STEAMGAME_USEVIRTUALMONITOR}" ]]; then
    echo -e "${REDERRORTAG} Variable STEAMGAME_USEVIRTUALMONITOR not set!"
    exit 1
fi
echo -e "${GREENSUCCESSTAG} Variables validation done!"

# --- Launch ---
export XDG_RUNTIME_DIR=/home/container/tmp/runtime
mkdir -p $XDG_RUNTIME_DIR
rm -rf ${XDG_RUNTIME_DIR:?}/* 
chmod 700 $XDG_RUNTIME_DIR
cd "/home/container/$(dirname "${STEAMGAME_PATHTOEXE}")"
export WINEPREFIX=/home/container/.wine

echo -e "${BLUEINFOTAG} Starting Server for STEAMGAME_APPID ${STEAMGAME_APPID} ..."
echo -e "${BLUEINFOTAG} Starting Server from STEAMGAME_PATHTOEXE ${STEAMGAME_PATHTOEXE} ..."
echo -e "${BLUEINFOTAG} Starting Server with STEAMGAME_STARTUPPARAMS ${STEAMGAME_STARTUPPARAMS} ..."

wineboot --init
wineserver -w
sleep 3
wineserver -k
sleep 3

if [[ "${STEAMGAME_USEVIRTUALMONITOR}" == "0" ]]; then
    wine "./$(basename "${STEAMGAME_PATHTOEXE}")" ${STEAMGAME_STARTUPPARAMS}
else
    echo -e "${BLUEINFOTAG} Starting Server with virtual monitor (Xvfb) ..."
    xvfb-run --auto-servernum --server-args="-screen 0 640x480x24 -ac" \
        wine "./$(basename "${STEAMGAME_PATHTOEXE}")" ${STEAMGAME_STARTUPPARAMS}
fi

EOF

# script execution permissions
RUN chmod +x /usr/local/bin/launch && chown container:container /usr/local/bin/launch
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# launch image script context setup
USER container
WORKDIR /home/container
CMD ["/usr/local/bin/launch"]
