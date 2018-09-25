FROM debian:9-slim

VOLUME /custom.d
EXPOSE 4000

ENV DEBIAN_FRONTEND=noninteractive
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

# Register pseudo-entrypoint
ADD ./entrypoint.sh /
RUN chmod a+x /entrypoint.sh
CMD ["/entrypoint.sh"]

# Set "real" entrypoint to an init system.
# TODO: Replace with --init when docker 18.06 is GA
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

# Get build dependencies
RUN \
       apt-get update \
    && apt-get install -y --no-install-recommends git wget ca-certificates gnupg2 build-essential \
    && wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb \
    && dpkg -i erlang-solutions_1.0_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends esl-erlang elixir \
    && rm -rf /var/lib/apt/lists/*

# Limit permissions
ARG DOCKER_UID
ARG DOCKER_GID
ARG PLEROMA_UPLOADS_PATH

RUN \
       groupadd --gid ${DOCKER_GID} pleroma \
    && useradd -m -s /bin/bash --gid ${DOCKER_GID} --uid ${DOCKER_UID} pleroma \
    && mkdir -p /custom.d $PLEROMA_UPLOADS_PATH \
    && chown -R pleroma:pleroma /custom.d $PLEROMA_UPLOADS_PATH

USER pleroma
WORKDIR /home/pleroma

# Get pleroma
RUN git clone --progress https://git.pleroma.social/pleroma/pleroma.git ./pleroma
WORKDIR /home/pleroma/pleroma

# Get rebar/hex
RUN \
       mix local.hex --force \
    && mix local.rebar --force

# Bust the build cache
ARG __BUST_CACHE
ENV __BUST_CACHE $__BUST_CACHE

# Fetch changes, checkout
ARG PLEROMA_VERSION

RUN \
       git fetch --all \
    && git checkout $PLEROMA_VERSION \
    && git pull --rebase --autostash

# Insert overrides and config helper
COPY --chown=pleroma:pleroma ./docker-config.exs /docker-config.exs
COPY --chown=pleroma:pleroma ./custom.d /home/pleroma/pleroma

# Precompile
RUN \
       ln -s /docker-config.exs config/prod.secret.exs \
    && ln -s /docker-config.exs config/dev.secret.exs \
    && mix deps.get \
    && mix compile

# Strip container
USER root
RUN \
       apt-get remove -y build-essential wget git gnupg2 \
    && apt-get autoremove -y
USER pleroma
