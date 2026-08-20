#!/usr/bin/env bash
set -Eeuo pipefail
export REPO_URL=${REPO_URL:-https://github.com/router-for-me/CLIProxyAPI.git}
export APP_DIR=${APP_DIR:-/opt/CLIProxyAPI-official}
exec bash "$(dirname "$0")/install.sh"
