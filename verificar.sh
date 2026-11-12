#!/bin/bash
# =====================================================================
# verificar.sh — comprueba DENTRO de Ubuntu que todo quedó bien
# Uso: sudo bash /home/deploy/servidorprueba/verificar.sh [dominio]
# =====================================================================
DOMAIN="${1:-}"
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLA] $1"; }
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi; }

echo "== 1. Sistema"
echo "  $(lsb_release -ds 2>/dev/null)"
check "Swap activo" bash -c "swapon --show | grep -q ."
check "Script de lanzamiento terminó (LISTO)" grep -q '^LISTO' /var/log/lab.log

echo "== 2. Usuario de la app"
check "Existe 'deploy'" id deploy
check "'deploy' tiene sudo" bash -c "id -nG deploy | grep -qw sudo"

echo "== 3. Seguridad"
check "SSH: root bloqueado" bash -c "sshd -T | grep -qx 'permitrootlogin no'"
check "SSH: sin contraseñas" bash -c "sshd -T | grep -qx 'passwordauthentication no'"
check "fail2ban activo" systemctl is-active fail2ban
check "Parches automáticos activos" systemctl is-enabled unattended-upgrades

echo "== 4. Herramientas"
echo "  node $(node -v)  |  pnpm $(pnpm -v)  |  pm2 $(pm2 -v | tail -1)"

echo "== 5. App"
check "PM2: 'web' online" bash -c "sudo -iu deploy pm2 jlist | grep -q '\"status\":\"online\"'"
check "PM2 arranca al reiniciar" systemctl is-enabled pm2-deploy
check "App responde en el 3000" curl -fsS -m 10 http://127.0.0.1:3000

echo "== 6. Nginx"
check "Configuración válida" nginx -t
check "Nginx entrega la app por el 80" curl -fsS -m 10 http://127.0.0.1
if [ -n "$DOMAIN" ]; then
  check "HTTPS público ($DOMAIN)" curl -fsS -m 15 "https://$DOMAIN"
fi

echo "== 7. Respaldo"
check "Tarea diaria instalada" test -x /etc/cron.daily/lab-backup
