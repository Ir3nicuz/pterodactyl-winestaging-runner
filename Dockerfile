# Usinf wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# setting symlinks for system directories
USER root
#RUN mkdir -p /home/container/.local/share /home/container/.config \
#    && ln -s /home/container/.local/share /mnt/server/linux_local_share \
#    && ln -s /home/container/.config /mnt/server/linux_config \
#    && chown -R container:container /home/container





USER root

RUN mkdir -v -p /home/container/Windows_AppData

RUN mkdir -v -p /home/container/.local/share
RUN mkdir -v -p /home/container/.config

RUN ln -v -s /home/container/.local/share /home/container/Windows_AppData/LocalShare
RUN ln -v -s /home/container/.config /home/container/Windows_AppData/Config

RUN chown -R container:container /home/container




# back to standard
USER container
WORKDIR /mnt/server
