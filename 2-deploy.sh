#!/bin/bash
# =====================================================================
# 2-deploy.sh — MONTA (o ACTUALIZA) la app desde GitHub
#
# QUIÉN lo corre: el usuario 'deploy' (nunca root).
#   - La primera vez lo llama 1-launch.sh automáticamente.
#   - Para actualizar después de un git push:
#       sudo -iu deploy bash servidorprueba/2-deploy.sh
# =====================================================================
set -euo pipefail

REPO="https://github.com/GIT-tdrobotica-XSC/servidorprueba"
DIR="$HOME/servidorprueba"

if [ "$(id -u)" -eq 0 ]; then
  echo "No lo corras como root. Usa: sudo -iu deploy bash servidorprueba/2-deploy.sh"
  exit 1
fi

echo "== 1. Traer el código de GitHub"
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

echo "== 2. Instalar dependencias (pnpm, versión exacta del lockfile)"
cd "$DIR/app"
pnpm install --frozen-lockfile

echo "== 3. Compilar la app para producción"
pnpm build

echo "== 4. Arrancar o recargar con PM2 (puerto 3000)"
if pm2 describe web >/dev/null 2>&1; then
  pm2 reload web
else
  pm2 start pnpm --name web -- start -p 3000
fi
pm2 save   # recuerda la app para el próximo reinicio

echo "== 5. Comprobar"
sleep 3
curl -fsS -o /dev/null http://127.0.0.1:3000 && echo "App OK en el puerto 3000"
