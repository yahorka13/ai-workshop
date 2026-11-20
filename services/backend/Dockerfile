FROM oven/bun:1.4.3@sha256:ec06c3b6cea04192ae6770c434f668ca41d343ad19fa6472216c7b48be39c598 AS base
WORKDIR /app

# bin/check's target: frozen development dependencies and the whole service.
FROM base AS checks
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .

# bin/mutate's target: the checks image plus ps, which Stryker's process
# handling needs and the slim Bun image lacks. Nothing ships from it.
FROM checks AS mutate
RUN apt-get update \
  && apt-get install -y --no-install-recommends procps \
  && rm -rf /var/lib/apt/lists/*

# What the stack runs, and the default target: production dependencies only,
# as the unprivileged bun user.
FROM base AS runtime
ENV NODE_ENV=production
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production
COPY src ./src
# Each container applies the migration history before it serves; bin/seed
# runs the seed command in a local stack's container.
COPY tooling/migrate.ts tooling/seed.ts ./tooling/
USER bun
# Apply the history, then exec so the server is the container's main process
# and receives signals directly. The advisory lock makes this safe with any
# number of replicas: one applies, the others wait and then find it current.
CMD ["sh", "-c", "bun tooling/migrate.ts && exec bun src/index.ts"]
