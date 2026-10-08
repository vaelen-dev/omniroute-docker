#!/bin/sh
set -e

DATA_DIR="/app/data"
SYNC_DIR="/tmp/omniroute-sync"
BACKUP_REPO="https://x-access-token:${GITHUB_PAT}@github.com/vaelen-dev/omniroute-data.git"

echo "[Persistent-Sync] Initializing OmniRoute persistent storage..."
mkdir -p "$DATA_DIR"

if [ -n "$GITHUB_PAT" ]; then
    echo "[Persistent-Sync] Fetching database snapshot from vaelen-dev/omniroute-data..."
    rm -rf "$SYNC_DIR"
    if git clone --depth 1 "$BACKUP_REPO" "$SYNC_DIR" 2>/dev/null; then
        if [ -f "$SYNC_DIR/storage.sqlite" ]; then
            DB_SIZE=$(wc -c < "$SYNC_DIR/storage.sqlite" | tr -d ' ')
            echo "[Persistent-Sync] Restoring storage.sqlite ($DB_SIZE bytes)..."
            cp "$SYNC_DIR/storage.sqlite" "$DATA_DIR/storage.sqlite"
            chmod 666 "$DATA_DIR/storage.sqlite"
            echo "[Persistent-Sync] Restoration complete!"
        else
            echo "[Persistent-Sync] No existing database in repo yet; starting fresh."
        fi
    else
        echo "[Persistent-Sync] Warning: git clone failed or repo empty."
    fi
else
    echo "[Persistent-Sync] Warning: GITHUB_PAT not set."
fi

# Function to push changes to GitHub
push_db() {
    if [ -n "$GITHUB_PAT" ] && [ -f "$DATA_DIR/storage.sqlite" ]; then
        cd "$SYNC_DIR" 2>/dev/null || return 0
        git pull origin main 2>/dev/null || true
        cp "$DATA_DIR/storage.sqlite" "$SYNC_DIR/storage.sqlite"
        git config user.name "OmniRoute Sync"
        git config user.email "sync@omniroute.local"
        git add storage.sqlite
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            echo "[Persistent-Sync] Detected changes. Pushing to GitHub..."
            git commit -m "Auto-backup $(date -u '+%Y-%m-%d %H:%M:%SZ')" 2>/dev/null || true
            git push origin main 2>/dev/null && echo "[Persistent-Sync] Database snapshot successfully pushed to GitHub!" || echo "[Persistent-Sync] Push failed, retrying next cycle."
        fi
    fi
}

# Trap exit signals to push final database state before container shuts down
cleanup() {
    echo "[Persistent-Sync] Caught shutdown signal. Flushing final database state..."
    push_db
    exit 0
}
trap cleanup TERM INT

# Background periodic sync every 3 minutes
if [ -n "$GITHUB_PAT" ]; then
    (
        while true; do
            sleep 180
            push_db
        done
    ) &
fi

# Ensure default start command if not passed
if [ $# -eq 0 ]; then
    if [ -f "/app/scripts/dev/run-standalone.mjs" ]; then
        set -- node /app/scripts/dev/run-standalone.mjs
    elif [ -f "scripts/dev/run-standalone.mjs" ]; then
        set -- node scripts/dev/run-standalone.mjs
    elif [ -f "/app/dev/run-standalone.mjs" ]; then
        set -- node /app/dev/run-standalone.mjs
    elif [ -f "/app/server.js" ]; then
        set -- node /app/server.js
    else
        set -- node server.js
    fi
fi

echo "[Persistent-Sync] Launching OmniRoute service: $@"
cd /app

if [ -f "/app/scripts/check-permissions.sh" ]; then
    exec /app/scripts/check-permissions.sh "$@"
elif [ -f "/app/check-permissions.sh" ]; then
    exec /app/check-permissions.sh "$@"
else
    exec "$@"
fi