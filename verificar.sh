#!/bin/bash
# =====================================================================
# verificar.sh — comprueba DENTRO de Ubuntu que el servidor quedó bien
# Uso:  sudo bash verificar.sh            (o)  sudo bash verificar.sh midominio.com
# Cada línea muestra OK o FALLA y qué se está probando.
# =====================================================================
DOMAIN="${1:-demomateria.us.ci}"
ok()   { echo "  [OK]    $1"; }
fail() { echo "  [FALLA] $1"; }
check() { # check "descripción" comando...
  local d="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$d"; else fail "$d"; fi
}

echo "== 1. Sistema"
lsb_release -d 2>/dev/null | sed 's/^/  /'
check "Swap activo (memoria de emergencia)" swapon --show=NAME --noheadings
free -h | sed 's/^/  /'

echo "== 2. Usuarios y permisos"
check "Existe el usuario 'deploy'" id deploy
check "'deploy' pertenece al grupo sudo" bash -c "id -nG deploy | grep -qw sudo"

echo "== 3. Seguridad"
check "SSH: root no puede entrar" bash -c "sshd -T | grep -qi '^permitrootlogin no'"
check "SSH: contraseñas desactivadas" bash -c "sshd -T | grep -qi '^passwordauthentication no'"
check "fail2ban activo (banea intentos de fuerza bruta)" systemctl is-active fail2ban
check "Actualizaciones automáticas de seguridad" systemctl is-enabled unattended-upgrades
echo "  Firewall ufw (reglas escritas, no activado a propósito):"
ufw status 2>&1 | sed 's/^/    /'

echo "== 4. Programas instalados"
echo "  node:  $(node -v 2>&1)"
echo "  pnpm:  $(pnpm -v 2>&1)"
echo "  pm2:   $(pm2 -v 2>&1 | tail -1)"
echo "  nginx: $(nginx -v 2>&1)"

echo "== 5. La aplicación"
PID="$(sudo -u deploy -H pm2 pid web 2>/dev/null | tail -1)"
if [ -n "$PID" ] && [ "$PID" != "0" ]; then ok "PM2 mantiene viva la app 'web' (pid $PID)"; else fail "PM2: app 'web' no está corriendo"; fi
check "La app responde en el puerto interno 3000" curl -fsS -m 10 http://127.0.0.1:3000
check "PM2 arranca solo al reiniciar (servicio systemd)" bash -c "systemctl list-unit-files | grep -q '^pm2-deploy'"

echo "== 6. Nginx y HTTPS"
check "Configuración de nginx válida" nginx -t
check "nginx activo" systemctl is-active nginx
check "Nginx entrega la página por HTTP local" curl -fsS -m 10 -H "Host: $DOMAIN" http://127.0.0.1
check "HTTPS público responde ($DOMAIN)" curl -fsS -m 15 "https://$DOMAIN"
echo "  Certificado vence:"
certbot certificates 2>/dev/null | grep -E "Domains|Expiry" | sed 's/^/    /'

echo "== 7. Respaldo"
check "Tarea diaria de respaldo instalada" test -x /etc/cron.daily/backup-app
echo "  Probando el respaldo ahora mismo:"
/etc/cron.daily/backup-app && ls -lh /var/backups/app | sed 's/^/    /'

echo "== 8. Registro del arranque"
grep -q "^LISTO" /var/log/bootstrap.log 2>/dev/null && ok "El script de arranque terminó (LISTO)" || fail "bootstrap.log no muestra LISTO"
