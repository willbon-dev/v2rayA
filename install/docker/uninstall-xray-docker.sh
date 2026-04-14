#!/usr/bin/env sh
set -eu

INSTALL_DIR_DEFAULT="/opt/v2raya-xray"
DATA_DIR_DEFAULT="/var/lib/v2raya-xray"

usage() {
  cat <<EOF
Usage: $0 [--install-dir DIR] [--data-dir DIR] [--purge-data]

Uninstall the v2rayA Xray Docker deployment installed by install-xray-docker.sh.

Options:
  --install-dir DIR   Directory containing docker-compose.yml and .env
  --data-dir DIR      Data directory mounted to /etc/v2raya
  --purge-data        Remove the data directory after stopping the container
  -h, --help          Show this help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

ensure_root() {
  if [ "$(id -u)" -eq 0 ]; then
    return
  fi
  if command -v sudo >/dev/null 2>&1; then
    exec sudo sh "$0" "$@"
  fi
  echo "Error: this script requires root privileges. Re-run as root or install sudo." >&2
  exit 1
}

INSTALL_DIR="$INSTALL_DIR_DEFAULT"
DATA_DIR="$DATA_DIR_DEFAULT"
PURGE_DATA=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --data-dir)
      DATA_DIR="$2"
      shift 2
      ;;
    --purge-data)
      PURGE_DATA=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

ensure_root "$@"
need_cmd docker

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "Error: docker compose is not available." >&2
  exit 1
fi

if [ -f "$INSTALL_DIR/docker-compose.yml" ]; then
  (cd "$INSTALL_DIR" && $COMPOSE_CMD down --remove-orphans)
else
  echo "Warning: compose file not found in $INSTALL_DIR, skipping compose shutdown." >&2
fi

rm -f "$INSTALL_DIR/docker-compose.yml" "$INSTALL_DIR/.env"
rmdir "$INSTALL_DIR" 2>/dev/null || true

if [ "$PURGE_DATA" -eq 1 ] && [ -d "$DATA_DIR" ]; then
  rm -rf "$DATA_DIR"
fi

cat <<EOF
v2rayA Xray Docker deployment has been removed.

Install dir cleaned: $INSTALL_DIR
Data dir kept:       $DATA_DIR
EOF

if [ "$PURGE_DATA" -eq 1 ]; then
  echo "Data dir removed."
else
  echo "Data dir preserved. Re-run with --purge-data to delete it."
fi
