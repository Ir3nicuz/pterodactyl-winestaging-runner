# Usinf wine staging as basic image
FROM ghcr.io/parkervcp/yolks:wine_staging

# setting symlinks for system directories
USER root




# back to standard
USER container
WORKDIR /mnt/server
