FROM node:22-slim AS dependencies

RUN apt-get update && \
    apt-get install --no-install-recommends -y g++ make python3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app/website

COPY website/package*.json ./
RUN npm ci --omit=dev && \
    npm cache clean --force

FROM node:22-slim

ENV NODE_ENV=production \
    PORT=80

WORKDIR /app

COPY website ./website
COPY --from=dependencies /app/website/node_modules ./website/node_modules
COPY shared ./shared
COPY data/terminologue.template.sqlite data/siteconfig.template.json ./templates/
COPY --chmod=0755 docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

WORKDIR /app/website

EXPOSE 80

VOLUME ["/app/data"]

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "terminologue.js"]
