# Usinf wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# setting symlinks for system directories
USER root
RUN mkdir -p /home/container/.local/share /home/container/.config \
    && ln -s /home/container/.local/share /mnt/server/linux_local_share \
    && ln -s /home/container/.config /mnt/server/linux_config \
    && chown -R container:container /home/container

# back to standard
USER container
WORKDIR /mnt/server
