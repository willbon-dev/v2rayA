#!/usr/bin/env sh
set -eu

INSTALL_DIR_DEFAULT="/opt/v2raya-xray"
COMPOSE_URL_DEFAULT="https://raw.githubusercontent.com/willbon-dev/v2rayA/main/install/docker/docker-compose.xray.yml"

usage() {
  cat <<EOF
Usage: $0 [--install-dir DIR] [--pull] [--compose-url URL]

Update the v2rayA Xray Docker deployment installed by install-xray-docker.sh.

Options:
  --install-dir DIR   Directory containing docker-compose.yml and .env
  --pull              Explicitly pull the image before recreating the container
  --compose-url URL   Override the docker compose download URL
  -h, --help          Show this help
EOF
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command not found: $1" >&2
    exit 1
  fi
}

download_to() {
  url="$1"
  output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
    return
  fi
  if command -v wget >/dev/null 2>&1; then
    wget -qO "$output" "$url"
    return
  fi
  echo "Error: neither curl nor wget is available for downloading files." >&2
  exit 1
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
PULL_IMAGE=0
COMPOSE_URL="$COMPOSE_URL_DEFAULT"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      INSTALL_DIR="$2"
      shift 2
      ;;
    --pull)
      PULL_IMAGE=1
      shift
      ;;
    --compose-url)
      COMPOSE_URL="$2"
      shift 2
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

if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
  echo "Error: compose file not found: $INSTALL_DIR/docker-compose.yml" >&2
  exit 1
fi

cd "$INSTALL_DIR"
download_to "$COMPOSE_URL" "$INSTALL_DIR/docker-compose.yml"

if [ "$PULL_IMAGE" -eq 1 ]; then
  $COMPOSE_CMD pull
fi

$COMPOSE_CMD up -d

cat <<EOF
v2rayA Xray Docker deployment has been updated.

Install dir: $INSTALL_DIR

Manage it with:
  cd $INSTALL_DIR
  $COMPOSE_CMD ps
  $COMPOSE_CMD logs -f
EOF
