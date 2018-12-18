# The version of Alpine to use for the final image
# This should match the version of Alpine that the `elixir:1.7.2-alpine` image uses
ARG ALPINE_VERSION=3.8

FROM elixir:1.7.2-alpine AS builder

# The following are build arguments used to change variable parts of the image.
# The name of your application/release (required)
ARG APP_NAME=test_chain
# The version of the application we are building (required)
ARG APP_VSN=0.1.0
# The environment to build with
ARG MIX_ENV=prod
# Set this to true if this release is not a Phoenix app
ARG SKIP_GANACHE=false
# If you are using an umbrella project, you can change this
# argument to the directory the Phoenix app is in so that the assets
# can be built
ARG GANACHE_SUBDIR=priv/presets/ganache-cli

ENV SKIP_GANACHE=${SKIP_GANACHE} \
    APP_NAME=${APP_NAME} \
    APP_VSN=${APP_VSN} \
    MIX_ENV=${MIX_ENV}

# By convention, /opt is typically used for applications
WORKDIR /opt/app

# This step installs all the build tools we'll need
RUN apk update && \
  apk upgrade --no-cache && \
  apk add --no-cache \
    nodejs \
    npm \
    git \
    python \
    bash \
    build-base && \
  mix local.rebar --force && \
  mix local.hex --force

# This copies our app source code into the build container
COPY . .

RUN mix do deps.get, deps.compile, compile

RUN \
  git clone https://github.com/trufflesuite/ganache-cli.git ${GANACHE_SUBDIR} && \
  cd ${GANACHE_SUBDIR} && \
  npm install && \
  ./node_modules/.bin/webpack-cli --config ./webpack/webpack.docker.config.js && \
  # Copy built files
  mkdir -p /opt/ganache && \
  mkdir -p /opt/ganache/node_modules/scrypt/build/Release && \
  mv ./node_modules/scrypt/build/Release /opt/ganache/node_modules/scrypt/build/Release/ && \
  mkdir -p /opt/ganache/node_modules/ganache-core/node_modules/scrypt/build/Release && \
  mv ./node_modules/ganache-core/node_modules/scrypt/build/Release /opt/ganache/node_modules/ganache-core/node_modules/scrypt/build/Release/ && \
  mkdir -p /opt/ganache/node_modules/ganache-core/node_modules/secp256k1/build/Release && \
  mv ./node_modules/ganache-core/node_modules/secp256k1/build/Release /opt/ganache/node_modules/ganache-core/node_modules/secp256k1/build/Release/ && \
  mkdir -p /opt/ganache/node_modules/ganache-core/node_modules/keccak/build/Release && \
  mv ./node_modules/ganache-core/node_modules/keccak/build/Release /opt/ganache/node_modules/ganache-core/node_modules/keccak/build/Release && \
  mkdir -p /opt/ganache/node_modules/sha3/build/Release && \
  mv ./node_modules/sha3/build/Release /opt/ganache/node_modules/sha3/build/Release && \
  mkdir -p /opt/ganache/node_modules/ganache-core/node_modules/websocket/build/Release && \
  mv ./node_modules/ganache-core/node_modules/websocket/build/Release /opt/ganache/node_modules/ganache-core/node_modules/websocket/build/Release && \
  mv ./build/ganache-core.docker.cli.js /opt/ganache && \
  mv ./build/ganache-core.docker.cli.js.map /opt/ganache && \
  ls -l /opt/ganache && \
  cd -

RUN \
  mkdir -p /opt/built && \
  mix release --verbose && \
  cp _build/${MIX_ENV}/rel/${APP_NAME}/releases/${APP_VSN}/${APP_NAME}.tar.gz /opt/built && \
  cd /opt/built && \
  tar -xzf ${APP_NAME}.tar.gz && \
  rm ${APP_NAME}.tar.gz


#######
#
# Running container
#
#######
FROM alpine:${ALPINE_VERSION}

# The name of your application/release (required)
ARG APP_NAME=test_chain

ARG PORT=4000

EXPOSE ${PORT}

WORKDIR /opt/app

RUN apk update && \
    apk add --no-cache \
      bash \
      openssl \
      geth \ 
      nodejs

ENV REPLACE_OS_VARS=true \
    APP_NAME=${APP_NAME} \
    PORT=${PORT}

COPY --from=builder /opt/built .
COPY --from=builder /opt/ganache /opt/built/priv/presets/ganache/

COPY ./priv/presets/geth /opt/built/priv/presets/geth
COPY ./priv/presets/ganache/wrapper.sh /opt/built/priv/presets/ganache

CMD trap 'exit' INT; /opt/app/bin/${APP_NAME} console