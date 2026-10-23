FROM node:24-bookworm-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev --ignore-scripts && mkdir /data && chown node:node /data
COPY relay ./relay
USER node
ENV PORT=4319 BIND_ADDRESS=0.0.0.0 NODE_ENV=production DATA_DIR=/data
EXPOSE 4319
CMD ["node", "relay/main.mjs"]
