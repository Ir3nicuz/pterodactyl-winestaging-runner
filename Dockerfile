# Usinf wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# setting symlinks for system directories
USER root
#RUN mkdir -p /home/container/.local/share /home/container/.config \
#    && ln -s /home/container/.local/share /mnt/server/linux_local_share \
#    && ln -s /home/container/.config /mnt/server/linux_config \
#    && chown -R container:container /home/container


# Schritt 1: Prüfen ob der User existiert und Ergebnis loggen
RUN echo "Prüfe User 'container'..." && id container

# Schritt 2: Verzeichnisse erstellen
RUN mkdir -v -p /home/container/.local/share
RUN mkdir -v -p /home/container/.config

# Schritt 4: Symlinks erstellen
RUN ln -v -s /home/container/.local/share /mnt/server/linux_local_share
RUN ln -v -s /home/container/.config /mnt/server/linux_config

# Schritt 5: Rechte vergeben und Ergebnis loggen
RUN chown -v -R container:container /home/container
RUN ls -la /home/container


# back to standard
USER container
WORKDIR /mnt/server
