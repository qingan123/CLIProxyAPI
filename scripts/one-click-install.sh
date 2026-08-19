#!/usr/bin/env bash
set -Eeuo pipefail
REPO_URL=https://github.com/router-for-me/CLIProxyAPI.git APP_DIR=${APP_DIR:-/opt/CLIProxyAPI} bash "$(dirname "$0")/install.sh"
