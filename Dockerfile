FROM node:18.18.2-alpine AS build_image

WORKDIR /app

ARG TARGETPLATFORM
ENV TARGETPLATFORM=${TARGETPLATFORM:-linux/amd64}

RUN \
  case "${TARGETPLATFORM}" in \
  'linux/arm64' | 'linux/arm/v7') \
  apk update && \
  apk add --no-cache python3 make g++ gcc libc6-compat bash && \
  yarn global add node-gyp \
  ;; \
  esac

COPY package.json yarn.lock ./
RUN CYPRESS_INSTALL_BINARY=0 yarn install --frozen-lockfile --network-timeout 1000000

COPY . ./

ARG COMMIT_TAG
ENV COMMIT_TAG=${COMMIT_TAG}

RUN yarn build

# remove development dependencies
RUN yarn install --production --ignore-scripts --prefer-offline

RUN rm -rf src server .next/cache

RUN mkdir -p config && touch config/DOCKER

# Create committag.json with proper fallback to 'local' if COMMIT_TAG is not provided
# This prevents version loop issues when building locally
RUN if [ -z "$COMMIT_TAG" ] || [ "$COMMIT_TAG" = "" ]; then \
      echo '{"commitTag": "local"}' > committag.json; \
    else \
      echo "{\"commitTag\": \"${COMMIT_TAG}\"}" > committag.json; \
    fi


FROM node:18.18.2-alpine

WORKDIR /app

# Install sqlite3 for database operations and other dependencies
RUN apk add --no-cache tzdata tini sqlite && rm -rf /tmp/*

# copy from build image
COPY --from=build_image /app ./

# Set production environment and ensure migrations run
ENV NODE_ENV=production
ENV RUN_MIGRATIONS=true

# Create a non-root user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S overseerr -u 1001

# Ensure config directory exists and has proper permissions
RUN mkdir -p /app/config && chown -R overseerr:nodejs /app/config

# Switch to non-root user
USER overseerr

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "yarn", "start" ]

EXPOSE 5055
