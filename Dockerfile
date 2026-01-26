# syntax=docker/dockerfile:1
# ^^^ This line must be the first in the script to activate the Heredoc-Feature.

# Use as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# Initials and environment
ARG ARG_BUILD_NUMBER=-1
ENV ENV_BUILD_NUMBER=${ARG_BUILD_NUMBER}
ENV REDERRORTAG='\e[31m[ERROR]\e[0m'
ENV GREENSUCCESSTAG='\e[32m[SUCCESS]\e[0m'
ENV YELLOWWARNINGTAG='\e[33m[WARNING]\e[0m'
ENV BLUEINFOTAG='\e[34m[INFO]\e[0m'
ENV LOGGING_DIRECTORY="/home/container/logs"
ENV WINE_LOGGING_FILE="${LOGGING_DIRECTORY}/wine_server_runner.log"
ENV GAME_LOGGING_FILE="${LOGGING_DIRECTORY}/game_server_runner.log"
ENV WINE_MONO_VERSION="9.4.0"
ENV WINE_GECKO_VERSION="2.47.4"
ENV CPPREDIST_FILE="vc_redist.x64.exe"

ENV WINEDEBUG=-all,err+all
ENV WINEARCH=win64
ENV WINEIPX=d
ENV WINEPREFIX="/home/container/.wine"
ENV WINEDLLOVERRIDES="mscoree=n,b;mshtml=d;msvcp140=n,b;msvcp140_1=n,b;msvcp140_2=n,b;vcruntime140=n,b;vcruntime140_1=n,b;vcomp140=n,b;ucrtbase=n,b;vcruntime140_threads=n,b"
ENV GNUTLS_SYSTEM_PRIORITY_FILE="/etc/gnutls/default-priorities"
ENV XDG_RUNTIME_DIR="/home/container/tmp/runtime"

USER root

# Tools and Helper integration
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps cabextract wget xvfb xauth winbind strace apache2-utils \
    ca-certificates p11-kit p11-kit-modules libp11-kit0 libp11-kit0:i386 libgnutls30:i386 libgnutls30 \
    && update-ca-certificates \
    && wget -q -O "/usr/local/bin/winetricks" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" \
    && chmod +x /usr/local/bin/winetricks \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /usr/share/wine/mono /usr/share/wine/gecko /usr/share/wine/vc_redist \
    && wget -q -O "/usr/share/wine/mono/wine-mono-installer.msi" "https://dl.winehq.org/wine/wine-mono/${WINE_MONO_VERSION}/wine-mono-${WINE_MONO_VERSION}-x86.msi" \
    && wget -q -O "/usr/share/wine/gecko/wine-gecko-installer_32bit.msi" "https://dl.winehq.org/wine/wine-gecko/${WINE_GECKO_VERSION}/wine-gecko-${WINE_GECKO_VERSION}-x86.msi" \
    && wget -q -O "/usr/share/wine/gecko/wine-gecko-installer_64bit.msi" "https://dl.winehq.org/wine/wine-gecko/${WINE_GECKO_VERSION}/wine-gecko-${WINE_GECKO_VERSION}-x86_64.msi" \
    && wget -q -O "/usr/share/wine/vc_redist/vcredist_installer.exe" "https://aka.ms/vs/17/release/${CPPREDIST_FILE}"

# Here-Doc definition of launch script
RUN <<'EOF' cat > /usr/local/bin/launch
#!/bin/bash
    # --- Settings ---
    XVFBRUNTIME_ARGS=(--auto-servernum --server-args="-screen 0 640x480x24 -ac -nolisten unix -extension MIT-SHM")
    GREPWINELOGS_ARGS="^[0-9a-f]{4}:|err:|fixme:"
    GREPGAMELOGS_ARGS=(--line-buffered -vE "(memorysetup-|allocator-)")
    ROTATELOGS_ARGS=(-n 3 "${GAME_LOGGING_FILE}" 10M)

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
    if [[ "${STEAMGAME_STARTUPPARAMS+defined}" != "defined" ]]; then
        echo -e "${REDERRORTAG} Variable STEAMGAME_STARTUPPARAMS not set!"
        exit 1
    fi
    if [[ -z "${STEAMGAME_USEVIRTUALMONITOR}" ]]; then
        echo -e "${REDERRORTAG} Variable STEAMGAME_USEVIRTUALMONITOR not set!"
        exit 1
    fi
    echo -e "${GREENSUCCESSTAG} Variables validation done!"
    
    # --- Runtime preperation  ---
    cd "/home/container/$(dirname "${STEAMGAME_PATHTOEXE}")"
    mkdir -p "${XDG_RUNTIME_DIR}" && chmod 700 "${XDG_RUNTIME_DIR}"
    rm -rf "${XDG_RUNTIME_DIR:?}"/* 
    echo -e "${BLUEINFOTAG} XDG_RUNTIME_DIR set to ${XDG_RUNTIME_DIR}"
    
    # --- Wine preperation  ---
    mkdir -p /home/container/Windows_AppData/{Roaming,Local,LocalLow,Documents} && chmod -R 755 /home/container/Windows_AppData
    WINE_INIT_VERSION=${WINEPREFIX}/initializedWith
    if [[ ! -f "${WINE_INIT_VERSION}" ]] || [[ "$(<"${WINE_INIT_VERSION}")" != "${ENV_BUILD_NUMBER}" ]]; then
        echo -e "${BLUEINFOTAG} Initializing Wine detected! (this may take a while) ..."
        xvfb-run "${XVFBRUNTIME_ARGS[@]}" /usr/local/bin/.winesetup && {
            echo "${ENV_BUILD_NUMBER}" > "${WINE_INIT_VERSION}"
            echo -e "${GREENSUCCESSTAG} Initializing Wine done!"
        } || {
            echo -e "${REDERRORTAG} Wine initialization failed!"
        }
    fi
    xvfb-run "${XVFBRUNTIME_ARGS[@]}" /usr/local/bin/.winesetupreport
    
    # --- Launch ---
    echo -e "${BLUEINFOTAG} Starting Server for STEAMGAME_APPID ${STEAMGAME_APPID} ..."
    echo -e "${BLUEINFOTAG} Starting Server from STEAMGAME_PATHTOEXE ${STEAMGAME_PATHTOEXE} ..."
    echo -e "${BLUEINFOTAG} Starting Server with STEAMGAME_STARTUPPARAMS ${STEAMGAME_STARTUPPARAMS} ..."

    mkdir -p "${LOGGING_DIRECTORY}" && : > "${WINE_LOGGING_FILE}"
    
    if [[ "${STEAMGAME_USEVIRTUALMONITOR}" == "0" ]]; then
        echo -e "${BLUEINFOTAG} Starting Server without virtual monitor (Xvfb) ..."
        wine "./$(basename "${STEAMGAME_PATHTOEXE}")" "${STEAMGAME_STARTUPPARAMS}" 2>&1 \
            | tee >(grep -E "${GREPWINELOGS_ARGS}" >> "${WINE_LOGGING_FILE}") \
            | grep --line-buffered -vE "${GREPWINELOGS_ARGS}" \
            | grep -E "${GREPGAMELOGS_ARGS[@]}" | tee /dev/tty | rotatelogs "${ROTATELOGS_ARGS[@]}"
    else
        echo -e "${BLUEINFOTAG} Starting Server with virtual monitor (Xvfb) ..."
        xvfb-run "${XVFBRUNTIME_ARGS[@]}" \
            wine "./$(basename "${STEAMGAME_PATHTOEXE}")" "${STEAMGAME_STARTUPPARAMS}" 2>&1 \
                | tee >(grep -E "${GREPWINELOGS_ARGS}" >> "${WINE_LOGGING_FILE}") \
                | grep --line-buffered -vE "${GREPWINELOGS_ARGS}" \
                | grep -E "${GREPGAMELOGS_ARGS[@]}" | tee /dev/tty | rotatelogs "${ROTATELOGS_ARGS[@]}"
    fi
EOF

RUN <<'EOF' cat > /usr/local/bin/.winesetup
#!/bin/bash
    # cleanup of logging background process on exit
    cleanup() {
        exec >&- 2>&-
        if [ -n "${loggingrelay:-}" ]; then
            exec {loggingrelay}>&-
        fi
        if [ -n "${LOGGINGRELAY_PID:-}" ]; then
            wait ${LOGGINGRELAY_PID} 2>/dev/null
        fi
    }
    trap cleanup EXIT
    set -e
    
    # prepare error logging tagging background process
    exec {loggingrelay}> >(sed -u -E "s/^([0-9a-f]{4}:|err:|fixme:)/$(echo -e "${YELLOWWARNINGTAG}") \1/")
    LOGGINGRELAY_PID=$!
    exec >&${loggingrelay} 2>&1

    # wine basic initialization
    echo -e "${BLUEINFOTAG} Starting Basic init ..."
    WINEDLLOVERRIDES="mscoree=;mshtml=" wineboot --init
    wineserver -w

    # replacing the wine standard windows user pathes with more toplevel ones
    echo -e "${BLUEINFOTAG} Starting Registry init ..."
    printf '%s\n\n' 'Windows Registry Editor Version 5.00' > /tmp/folders.reg
    
    printf '%s\n' '[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders]' >> /tmp/folders.reg
    printf '%s\n' '"Personal"="Z:\\home\\container\\Windows_AppData\\Documents"' >> /tmp/folders.reg
    printf '%s\n' '"AppData"="Z:\\home\\container\\Windows_AppData\\Roaming"' >> /tmp/folders.reg
    printf '%s\n' '"Local AppData"="Z:\\home\\container\\Windows_AppData\\Local"' >> /tmp/folders.reg
    printf '%s\n' '"LocalLow"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"Local Low"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"{A5202746-AD22-4744-A945-D1D53E99215A}"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"{A520A1A4-1780-4FF6-BD18-167343C5AF16}"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    
    printf '%s\n' '[HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders]' >> /tmp/folders.reg
    printf '%s\n' '"Personal"="Z:\\home\\container\\Windows_AppData\\Documents"' >> /tmp/folders.reg
    printf '%s\n' '"AppData"="Z:\\home\\container\\Windows_AppData\\Roaming"' >> /tmp/folders.reg
    printf '%s\n' '"Local AppData"="Z:\\home\\container\\Windows_AppData\\Local"' >> /tmp/folders.reg
    printf '%s\n' '"LocalLow"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"Local Low"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"{A5202746-AD22-4744-A945-D1D53E99215A}"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    printf '%s\n' '"{A520A1A4-1780-4FF6-BD18-167343C5AF16}"="Z:\\home\\container\\Windows_AppData\\LocalLow"' >> /tmp/folders.reg
    
    wine regedit /S /tmp/folders.reg
    wineserver -w

    # install mono(.net framework), gecko(html) and c++ runtime sub modules
    echo -e "${BLUEINFOTAG} Installing Mono ..."
    msiexec /i /usr/share/wine/mono/wine-mono-installer.msi /qn
    wineserver -w
    echo -e "${BLUEINFOTAG} Installing Gecko 32bit ..."
    msiexec /i /usr/share/wine/gecko/wine-gecko-installer_32bit.msi /qn
    wineserver -w
    echo -e "${BLUEINFOTAG} Installing Gecko 64bit ..."
    msiexec /i /usr/share/wine/gecko/wine-gecko-installer_64bit.msi /qn
    wineserver -w
    echo -e "${BLUEINFOTAG} Installing Visual C++ Redist ..."
    wine /usr/share/wine/vc_redist/vcredist_installer.exe /install /quiet /norestart
    wineserver -w

    # kill and fresh launch wine server and ignore errors
    wineserver -k || true
EOF

RUN <<'EOF' cat > /usr/local/bin/.winesetupreport
#!/bin/bash
    echo -e "${BLUEINFOTAG} Wine setup report:"
    
    # Wine Version
    printf "    %-15s Version: %s\n" "Wine:" "$(wine --version)"

    # reading registry
    INSTALLED_WINEADDON_MODULES=$(wine reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall" /s 2>/dev/null | grep -iE "DisplayName|DisplayVersion" | tr -d '\r')
    INSTALLED_WINEADDON_MODULES+=$'\n'$(wine reg query "HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" /s 2>/dev/null | grep -iE "DisplayName|DisplayVersion" | tr -d '\r')
    
    # check the Gecko (Html) registrated Package
    if echo "${INSTALLED_WINEADDON_MODULES}" | grep -qi "Gecko"; then
        echo "${INSTALLED_WINEADDON_MODULES}" | grep "DisplayName" | grep "Gecko" | while read -r gecko_entryline; do
            WINEADDON_GECKO_NAME=$(echo "${gecko_entryline}" | sed 's/.*REG_SZ//' | xargs)
            WINEADDON_GECKO_VERSION=$(echo "${INSTALLED_WINEADDON_MODULES}" | grep -A 1 "${WINEADDON_GECKO_NAME}" | grep "DisplayVersion" | sed 's/.*REG_SZ//' | xargs)
            printf "    %-15s Version: %s (%s)\n" "Gecko (Html):" "${WINEADDON_GECKO_VERSION:-N/A}" "${WINEADDON_GECKO_NAME}"
        done
    else
        echo -e "${REDERRORTAG} No Wine Gecko (Html) installation found in wine registry!"
    fi

    # check the Visual C++ registrated Packages
    if echo "${INSTALLED_WINEADDON_MODULES}" | grep -q "Visual C++"; then
        echo "${INSTALLED_WINEADDON_MODULES}" | grep "DisplayName" | grep "Visual C++" | while read -r cppredistributable_entryline; do
            WINEADDON_CPPREDIST_NAME=$(echo "${cppredistributable_entryline}" | sed 's/.*REG_SZ//' | xargs)
            printf "    %-15s Version: %s\n" "Visual C++:" "${WINEADDON_CPPREDIST_NAME}"
        done
    else
        echo -e "${REDERRORTAG} No Visual C++ Redistributable installation found in wine registry!"
    fi
    
    # check the .Net Framework (Mono) registrated Packages
    NETFRAMEWORK_MODULECOUNT=0
    while read -r netframework_entryline; do
        if [[ ${netframework_entryline} == HKEY* ]]; then
            NETFRAMEWORK_VERSIONNAME=$(echo "${netframework_entryline}" | awk -F'\\' '{print $NF}' | xargs)
            continue
        fi
        
        NETFRAMEWORK_VERSIONVALUE=$(echo "${netframework_entryline}" | sed 's/.*REG_SZ//' | xargs)
        printf "    .NET Framework (Mono):    %-15s Version: %s\n" "${NETFRAMEWORK_VERSIONNAME}" "${NETFRAMEWORK_VERSIONVALUE}"
        
        ((NETFRAMEWORK_MODULECOUNT++))
    done < <(wine reg query "HKLM\Software\Microsoft\NET Framework Setup\NDP" /s 2>/dev/null | tr -d '\r' | grep -E "HKEY|Version")
    if [ "${NETFRAMEWORK_MODULECOUNT}" -eq 0 ]; then
        echo -e "${REDERRORTAG} No .NET Framework (Mono) installations found in wine registry!"
    fi
EOF

# script permissions and pathes out of container
RUN chmod +x /usr/local/bin/launch && chown container:container /usr/local/bin/launch \
    && chmod +x /usr/local/bin/.winesetup && chown container:container /usr/local/bin/.winesetup \
    && chmod +x /usr/local/bin/.winesetupreport && chown container:container /usr/local/bin/.winesetupreport \
    && mkdir -p /etc/gnutls && echo "@SYSTEM" > /etc/gnutls/default-priorities && chmod 644 /etc/gnutls/default-priorities

# launch image script context setup
USER container
WORKDIR /home/container
CMD ["/usr/local/bin/launch"]
