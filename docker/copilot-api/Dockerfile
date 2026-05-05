# copilot-api as a long-running service.
# Pinned node 22 LTS + alpine for size.
FROM node:22-alpine

# wget is needed by compose healthcheck
RUN apk add --no-cache wget

RUN npm install -g copilot-api@latest

EXPOSE 4141

# --host 0.0.0.0 so other compose services (litellm) can reach us via DNS
CMD ["copilot-api", "start", "--port", "4141"]
