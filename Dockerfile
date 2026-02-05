# syntax=docker/dockerfile:1
ARG ELIXIR_VERSION=1.17.0-otp-27
ARG OTP_VERSION=27
ARG DEBIAN_VERSION=bookworm-20241009-slim
ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

# ---- Build stage ----
FROM ${BUILDER_IMAGE} as builder

RUN apt-get update -y && apt-get install -y build-essential git curl unzip nodejs npm \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

# Install Hex + Rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build-time env vars
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV

# Copy config (includes runtime.exs for prod)
COPY config config

# Compile dependencies
RUN mix deps.compile

# Copy assets and source
COPY assets assets
COPY priv priv
COPY lib lib

# Compile application and assets (compile before assets.deploy per Phoenix docs)
RUN mix compile
RUN mix assets.deploy

# ---- Release stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

RUN chown nobody /app

# Set runtime env
ENV MIX_ENV="prod"
ENV PHX_SERVER=true

# Copy full build artifacts (needed for mix phx.server without releases)
COPY --from=builder --chown=nobody:root /app/_build ./_build
COPY --from=builder --chown=nobody:root /app/deps ./deps
COPY --from=builder --chown=nobody:root /app/priv ./priv
COPY --from=builder --chown=nobody:root /app/config ./config
COPY --from=builder --chown=nobody:root /app/lib ./lib
COPY --from=builder --chown=nobody:root /app/mix.exs mix.lock ./

USER nobody

CMD ["mix", "phx.server"]
