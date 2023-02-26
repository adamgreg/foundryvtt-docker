ARG FOUNDRY_PASSWORD
ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_USERNAME
ARG FOUNDRY_VERSION=10.291
ARG NODE_IMAGE_VERSION=16-alpine3.15

FROM node:${NODE_IMAGE_VERSION} as compile-typescript-stage

WORKDIR /root

COPY \
  package.json \
  package-lock.json \
  tsconfig.json \
  ./
RUN npm install && npm install --global typescript
COPY /src/*.ts src/
RUN tsc
RUN grep -l "#!" dist/*.js | xargs chmod a+x

FROM node:${NODE_IMAGE_VERSION} as optional-release-stage

ARG FOUNDRY_PASSWORD
ARG FOUNDRY_RELEASE_URL
ARG FOUNDRY_USERNAME
ARG FOUNDRY_VERSION
ENV ARCHIVE="foundryvtt-${FOUNDRY_VERSION}.zip"

WORKDIR /root
COPY --from=compile-typescript-stage \
  /root/package.json \
  /root/package-lock.json \
  /root/dist/authenticate.js \
  /root/dist/get_release_url.js \
  /root/dist/logging.js \
  ./
# .placeholder file to mitigate https://github.com/moby/moby/issues/37965
RUN mkdir dist && touch dist/.placeholder
RUN \
  if [ -n "${FOUNDRY_USERNAME}" ] && [ -n "${FOUNDRY_PASSWORD}" ]; then \
  npm install && \
  ./authenticate.js "${FOUNDRY_USERNAME}" "${FOUNDRY_PASSWORD}" cookiejar.json && \
  s3_url=$(./get_release_url.js --retry 5 cookiejar.json "${FOUNDRY_VERSION}") && \
  wget -O ${ARCHIVE} "${s3_url}" && \
  unzip -d dist ${ARCHIVE} 'resources/*'; \
  elif [ -n "${FOUNDRY_RELEASE_URL}" ]; then \
  wget -O ${ARCHIVE} "${FOUNDRY_RELEASE_URL}" && \
  unzip -d dist ${ARCHIVE} 'resources/*'; \
  fi


FROM golang:1.20-alpine as gcsfuse-stage

# Build gcsfuse
RUN apk --update add git fuse fuse-dev;
RUN GO111MODULE=auto go get -u github.com/googlecloudplatform/gcsfuse

FROM node:${NODE_IMAGE_VERSION} as final-stage

ARG FOUNDRY_UID=421
ARG FOUNDRY_VERSION
ARG DATA_BUCKET

LABEL com.foundryvtt.version=${FOUNDRY_VERSION}
LABEL org.opencontainers.image.authors="markf+github@geekpad.com"
LABEL org.opencontainers.image.vendor="Geekpad"

ENV FOUNDRY_HOME="/home/foundry"
ENV FOUNDRY_UID=${FOUNDRY_UID}
ENV FOUNDRY_VERSION=${FOUNDRY_VERSION}
ENV DATA_BUCKET=${DATA_BUCKET}

WORKDIR ${FOUNDRY_HOME}

# Add fuse (for gcsfuse mount of data dir) and tini
RUN apk --update add fuse tini

COPY --from=optional-release-stage /root/dist/ .
COPY --from=compile-typescript-stage /root/dist/ .
COPY --from=gcsfuse-stage /go/bin/gcsfuse /usr/bin
COPY \
  package.json \
  package-lock.json \
  src/check_health.sh \
  src/entrypoint.sh \
  src/launcher.sh \
  src/logging.sh \
  ./
RUN addgroup --system --gid ${FOUNDRY_UID} foundry \
  && adduser --system --uid ${FOUNDRY_UID} --ingroup foundry foundry \
  && apk --update --no-cache add \
  curl \
  jq \
  sed \
  su-exec \
  tzdata \
  && npm install

ENTRYPOINT ["/sbin/tini", "--", "./entrypoint.sh"]
CMD []
HEALTHCHECK --start-period=3m --interval=30s --timeout=5s CMD ./check_health.sh
