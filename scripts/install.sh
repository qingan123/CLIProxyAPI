#!/usr/bin/env bash
set -Eeuo pipefail
APP_DIR_BASE=${APP_DIR_BASE:-${APP_DIR:-/opt/CLIProxyAPI}}
PORT=${CLIPROXY_PORT:-8317}
REPO_URL=${REPO_URL:-https://github.com/qingan123/CLIProxyAPI.git}
fail(){ echo "ERROR: $*" >&2; exit 1; }
read_tty(){ local v; IFS= read -r -p "$1" v </dev/tty || fail '需要交互终端'; printf '%s' "$v"; }
read_secret(){ local v; IFS= read -r -s -p "$1" v </dev/tty || fail '需要交互终端'; printf '\n' >/dev/tty; printf '%s' "$v"; }
[[ $EUID -eq 0 ]] || fail '请使用 root/sudo'; command -v git >/dev/null || fail '缺少 git'; command -v docker >/dev/null || fail '缺少 docker'; docker compose version >/dev/null || fail '需要 Docker Compose v2'
PORT=$(read_tty "端口 [$PORT]: "); PORT=${PORT:-8317}; [[ $PORT =~ ^[0-9]+$ ]] || fail '端口无效'
APP_DIR="$APP_DIR_BASE"; [[ "$PORT" == 8317 ]] || APP_DIR="${APP_DIR_BASE}-${PORT}"
printf '安装目录自动设置为: %s\n' "$APP_DIR"
secret=$(read_secret '管理 API secret-key（留空自动生成）: '); [[ -n "$secret" ]] || secret=$(openssl rand -hex 32)
if command -v ss >/dev/null 2>&1; then
  for candidate in "$PORT" 8085 1455 54545 51121 11451; do
    ss -ltn "sport = :$candidate" | grep -q LISTEN && fail "端口 $candidate 已被占用"
  done
fi
mkdir -p "$APP_DIR"; [[ -z "$(find "$APP_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]] || fail '目标目录非空'
git clone --depth 1 --branch main "$REPO_URL" "$APP_DIR"; cd "$APP_DIR"
cp -n config.example.yaml config.yaml 2>/dev/null || true; mkdir -p auths logs plugins
python3 - "$PORT" "$secret" <<'PY'
from pathlib import Path
import re,sys
p=Path('config.yaml')
s=p.read_text()
s=re.sub(r'(?m)^port:\s*.*$', f'port: {sys.argv[1]}', s, count=1)
s=re.sub(r'(?m)^(\s*allow-remote:\s*).*$', lambda m: m.group(1)+'true', s, count=1)
s=re.sub(r'(?m)^(\s*secret-key:\s*).*$', lambda m: m.group(1)+sys.argv[2], s, count=1)
p.write_text(s)
Path('auths/management-secret.txt').write_text(sys.argv[2]+'\n', encoding='utf-8')
PY
sed -i -E "s/\"[0-9]+:8317\"/\"$PORT:$PORT\"/" docker-compose.yml
unset secret; chmod 600 config.yaml auths/management-secret.txt
docker compose up -d --pull always
for _ in {1..60}; do curl -fsS "http://127.0.0.1:$PORT/management.html" >/dev/null && break; sleep 1; done
curl -fsS "http://127.0.0.1:$PORT/management.html" >/dev/null || { docker compose logs --tail=100; exit 1; }
ip="${PUBLIC_HOST:-$(curl -4fsS --max-time 5 https://api.ipify.org || true)}"; url=${ip:+http://$ip:$PORT/management.html}; [[ -n "$url" ]] || url='公网IP探测失败，请检查安全组/UFW'; printf '部署完成。\n公网管理地址: %s\n本机管理地址: http://127.0.0.1:%s/management.html\n管理Secret保存于: %s/management-secret.txt（权限600）\n端口: %s（远程管理已开启，请妥善保管Secret）\n' "$url" "$PORT" "$APP_DIR" "$PORT"
