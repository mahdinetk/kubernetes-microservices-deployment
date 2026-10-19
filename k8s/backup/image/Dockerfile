FROM postgres:17

RUN apt-get update \
    && apt-get install -y --no-install-recommends pgbackrest \
    && rm -rf /var/lib/apt/lists/*

COPY kubectl /usr/local/bin/kubectl

RUN chmod 755 /usr/local/bin/kubectl
