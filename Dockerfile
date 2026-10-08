FROM diegosouzapw/omniroute:latest

USER root
RUN which git || (apt-get update && apt-get install -y git curl ca-certificates && rm -rf /var/lib/apt/lists/*) || apk add --no-cache git curl ca-certificates

WORKDIR /app
COPY entrypoint-sync.sh /app/entrypoint-sync.sh
RUN chmod +x /app/entrypoint-sync.sh

ENTRYPOINT ["/app/entrypoint-sync.sh"]
CMD ["node", "scripts/dev/run-standalone.mjs"]