#!/bin/bash
# =====================================================================
# bootstrap.sh — "script de arranque" (user-data) de Lightsail
# QUÉ ES: Lightsail lo ejecuta UNA vez, como root, al crear la instancia.
# POR QUÉ: así el servidor se arma solo y es reproducible: si se daña,
#          se crea otro idéntico en minutos sin repetir pasos a mano.
# =====================================================================
set -euxo pipefail                      # se detiene ante cualquier error (y muestra cada comando)
exec > /var/log/bootstrap.log 2>&1      # guarda todo en un log para depurar

# ---- Variables: lo único que hay que editar ----
DOMAIN="demomateria.us.ci"              # dominio gratis de DNSHE (cambiar por el que registres)
REPO="https://github.com/GIT-tdrobotica-XSC/servidorprueba.git"
EMAIL="git@tdrobotica.co"               # para avisos de vencimiento del certificado SSL
APP_USER="deploy"                       # usuario normal que correrá la app
export DEBIAN_FRONTEND=noninteractive   # evita preguntas interactivas en apt

# ---- 0. Memoria swap de 2 GB ----
# POR QUÉ: compilar Next.js gasta mucha RAM. Si se agota, el servidor se pone lentísimo
# o mata el proceso. El swap usa disco como RAM de emergencia.
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile && chmod 600 /swapfile
  mkswap /swapfile && swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
export NEXT_TELEMETRY_DISABLED=1

# ---- 1. Actualizaciones completas ----
# POR QUÉ: los parches de seguridad cierran vulnerabilidades conocidas.
apt-get update -y && apt-get upgrade -y
apt-get install -y nginx git curl ufw fail2ban unattended-upgrades certbot python3-certbot-nginx

# ---- 2. Usuario con sudo (no usar root) ----
# POR QUÉ: si la app es hackeada, el atacante solo tiene los permisos de "deploy".
id "$APP_USER" &>/dev/null || adduser --disabled-password --gecos "" "$APP_USER"
usermod -aG sudo "$APP_USER"
echo "$APP_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$APP_USER   # sudo sin clave (demo; en producción pedir clave)
mkdir -p /home/$APP_USER/.ssh && cp /home/ubuntu/.ssh/authorized_keys /home/$APP_USER/.ssh/ 2>/dev/null || true
chown -R $APP_USER:$APP_USER /home/$APP_USER/.ssh

# ---- 3. Seguridad ----
# SSH: sin login de root ni contraseñas (solo llaves). Frena fuerza bruta.
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/; s/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart ssh
# fail2ban: banea IPs que fallan muchas veces el login SSH.
systemctl enable --now fail2ban
# Parches de seguridad automáticos futuros.
dpkg-reconfigure -f noninteractive unattended-upgrades
# Firewall ufw: SE CONFIGURAN las reglas pero NO se activa aquí.
# POR QUÉ: en TDRobotica, activar ufw dentro del launch script cuelga cloud-init y, tras un
# reboot, ya dejó SSH bloqueado. El firewall principal es el de Lightsail (capa AWS,
# puertos 22/80/443). Para activar ufw: a mano, con snapshot previo (ver README).
ufw default deny incoming; ufw default allow outgoing
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp

# ---- 4. Node.js 22 + pnpm + PM2 ----
# Node ejecuta Next.js; pnpm instala dependencias; PM2 mantiene la app viva y la reinicia si cae.
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g pnpm pm2

# ---- 5. Bajar el código de GitHub y construirlo ----
sudo -u $APP_USER bash <<APP
set -e
cd /home/$APP_USER
rm -rf servidorprueba && git clone $REPO servidorprueba
cd servidorprueba/app
pnpm install --frozen-lockfile
pnpm build
pm2 start "pnpm start -p 3000" --name web
pm2 save
APP
# Que PM2 arranque solo cuando el servidor reinicia.
env PATH=$PATH pm2 startup systemd -u $APP_USER --hp /home/$APP_USER

# ---- 6. Nginx como proxy inverso ----
# POR QUÉ: Next.js escucha en el 3000 (interno). Nginx recibe 80/443 desde internet
# y reenvía a la app; además maneja el HTTPS.
cat > /etc/nginx/sites-available/app <<NGINX
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

# ---- 7. HTTPS gratis con Let's Encrypt ----
# REQUIERE que el DNS del dominio ya apunte a la IP del servidor; si no, falla y se
# reintenta luego a mano: sudo certbot --nginx -d DOMINIO
certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --no-eff-email --redirect -n || echo "Certbot falló: ¿ya apunta el DNS?"

# ---- 8. Respaldo ----
# Copia diaria (3am) de la app a /var/backups, conservando 7 días.
# Respaldo "grande": snapshots automáticos de Lightsail (se activan con aws cli, ver README).
cat > /etc/cron.daily/backup-app <<'CRON'
#!/bin/bash
mkdir -p /var/backups/app
tar czf /var/backups/app/app-$(date +%F).tar.gz /home/deploy/servidorprueba /etc/nginx/sites-available
find /var/backups/app -name '*.tar.gz' -mtime +7 -delete
CRON
chmod +x /etc/cron.daily/backup-app

echo "LISTO: https://$DOMAIN"
