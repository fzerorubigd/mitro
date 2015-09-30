FROM java:7
MAINTAINER fzerorubigd <fzero@rubi.gd>

ENV NODE_PATH /srv/mitro/browser-ext/api/build/node/lib/node_modules

RUN apt-get update && apt-get install -y --no-install-recommends \
        ssh \
        wget \
        git \
        tar \
        unzip \
        bzip2 \
        python-setuptools \
        ant \
        ant-optional \
    && rm -rf /var/lib/apt/lists/*
    
RUN easy_install argparse

RUN wget --quiet --no-check-certificate -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ jessie-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update && apt-get install -y --no-install-recommends \
        postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# mitro expects the keys to be in this dir
RUN mkdir -p /mitrocore_secrets/sign_keyczar

WORKDIR /srv/mitro
RUN git clone https://github.com/mitro-co/mitro.git /srv/mitro

# apply browser-ext patch and static files patch
COPY ./lru_patch.diff /srv/mitro/
COPY ./static_files.diff /srv/mitro/
RUN git apply lru_patch.diff
RUN git apply static_files.diff

WORKDIR /srv/mitro/mitro-core

COPY ./docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["ant", "server"]
