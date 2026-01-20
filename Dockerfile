# Usinf wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# setting symlinks for system directories
USER root





# 1. Notwendige Bibliotheken für Sound-Dummys und 7D2D Abhängigkeiten
RUN apt-get update && apt-get install -y \
    libasound2 \
    libasound2-plugins \
    alsa-utils \
    && apt-get clean

# 2. Wine-Umgebung festlegen (64-Bit ist Pflicht für 7D2D)
ENV WINEARCH=win64
ENV WINEPREFIX=/home/container/.wine
ENV WINEDEBUG=-all
# Audio-Treiber auf 'null' setzen, um ALSA-Fehler zu vermeiden
ENV WINEDLLOVERRIDES="winealsa.drv,winemmoe.drv=d"


# Wechsel zum User container für die Initialisierung
USER container
RUN wineboot -u && wineserver -w




# back to standard
USER container
WORKDIR /mnt/server
