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

# The app's static files, in /app/dist. VITE_API_URL is the API's origin the
# page calls; the session stack sets it per slot, and a build without one
# serves a page that shows the API as not configured and sends no request.
FROM checks AS build
ARG VITE_API_URL=""
RUN bun run build

# The component gallery's static files, in /app/storybook-static.
FROM checks AS storybook-build
RUN bun run build-storybook

# What the stack runs, and the default target: the built files on pinned,
# unprivileged nginx, which runs as its non-root user and installs nothing.
FROM nginxinc/nginx-unprivileged:1.30.6-alpine3.24@sha256:f5116ed4606f3eb015dd4a8e28cb9b351476dc0ad4bc6e9f93b19cec130cdf03 AS runtime
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
COPY --from=storybook-build /app/storybook-static /usr/share/nginx/html/storybook
EXPOSE 3000
