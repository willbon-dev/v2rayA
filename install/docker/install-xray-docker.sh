#!/usr/bin/env sh
set -eu

IMAGE_DEFAULT="willbon/v2raya:v2.2.7.5-xray"
CONTAINER_DEFAULT="v2raya-xray"
INSTALL_DIR_DEFAULT="/opt/v2raya-xray"
DATA_DIR_DEFAULT="/var/lib/v2raya-xray"
COMPOSE_URL_DEFAULT="https://raw.githubusercontent.com/willbon-dev/v2rayA/main/install/docker/docker-compose.xray.yml"

usage() {
  cat <<EOF
Usage: $0 [--install-dir DIR] [--data-dir DIR] [--image IMAGE] [--name NAME] [--compose-url URL]

Install the v2rayA Xray Docker deployment using the compose file published in the GitHub repo.

Options:
  --install-dir DIR   Directory to store docker-compose.yml and .env
  --data-dir DIR      Directory to store v2rayA data mounted to /etc/v2raya
  --image IMAGE       Docker image to deploy
  --name NAME         Container name
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
DATA_DIR="$DATA_DIR_DEFAULT"
IMAGE="$IMAGE_DEFAULT"
CONTAINER_NAME="$CONTAINER_DEFAULT"
COMPOSE_URL="$COMPOSE_URL_DEFAULT"

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
    --image)
      IMAGE="$2"
      shift 2
      ;;
    --name)
      CONTAINER_NAME="$2"
      shift 2
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
need_cmd install
need_cmd mkdir

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD="docker-compose"
else
  echo "Error: docker compose is not available." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$DATA_DIR"
install -m 755 -d "$INSTALL_DIR" "$DATA_DIR"
download_to "$COMPOSE_URL" "$INSTALL_DIR/docker-compose.yml"

cat >"$INSTALL_DIR/.env" <<EOF
V2RAYA_IMAGE=$IMAGE
V2RAYA_CONTAINER_NAME=$CONTAINER_NAME
V2RAYA_DATA_DIR=$DATA_DIR
EOF

(cd "$INSTALL_DIR" && $COMPOSE_CMD up -d)

cat <<EOF
v2rayA Xray Docker deployment has been installed.

Install dir: $INSTALL_DIR
Data dir:    $DATA_DIR
Image:       $IMAGE
Container:   $CONTAINER_NAME

Manage it with:
  cd $INSTALL_DIR
  $COMPOSE_CMD ps
  $COMPOSE_CMD logs -f
  $COMPOSE_CMD restart
EOF
