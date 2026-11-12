#!/bin/bash
# =====================================================================
# 1-launch.sh — SCRIPT DE LANZAMIENTO de Lightsail (se pega completo)
#
# QUIÉN lo corre: Lightsail (cloud-init), como ROOT, UNA sola vez,
#                 al crear la instancia.
# QUÉ hace:       prepara Ubuntu 24.04 (sistema, usuario, seguridad,
#                 herramientas, nginx, respaldo) y al final llama a
#                 2-deploy.sh como usuario normal para montar la app.
# LOG:            /var/log/lab.log  (y /var/log/cloud-init-output.log)
# =====================================================================
set -euxo pipefail
exec > >(tee -a /var/log/lab.log) 2>&1

REPO="${REPO:-https://github.com/GIT-tdrobotica-XSC/servidorprueba}"
APP_USER="deploy"
export DEBIAN_FRONTEND=noninteractive   # apt no hace preguntas
export NEEDRESTART_MODE=a               # reinicia servicios sin preguntar

# ---- 1. Swap de 2 GB (memoria de emergencia en disco) ----
# Compilar Next.js gasta mucha RAM; sin swap el servidor se cuelga.
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  if swapon /swapfile; then
    grep -q /swapfile /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  else
    echo "AVISO: no se pudo activar swap; sigo sin él."
  fi
fi

# ---- 2. Actualizaciones + paquetes base ----
apt-get update
apt-get -y upgrade
apt-get install -y git curl nginx fail2ban ufw \
  unattended-upgrades certbot python3-certbot-nginx libatomic1

# ---- 3. Usuario de la app (no usar root para la app) ----
if ! id "$APP_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$APP_USER"
fi
usermod -aG sudo "$APP_USER"
echo "$APP_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-$APP_USER
chmod 440 /etc/sudoers.d/90-$APP_USER
# Copia la llave SSH de 'ubuntu' para poder entrar como deploy.
install -d -m 700 -o "$APP_USER" -g "$APP_USER" /home/$APP_USER/.ssh
install -m 600 -o "$APP_USER" -g "$APP_USER" \
  /home/ubuntu/.ssh/authorized_keys /home/$APP_USER/.ssh/authorized_keys

# ---- 4. Seguridad ----
# SSH: archivo propio en sshd_config.d (no se edita el original).
cat > /etc/ssh/sshd_config.d/00-lab.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
EOF
systemctl reload ssh || true
systemctl enable --now fail2ban          # banea IPs que atacan SSH
systemctl enable --now unattended-upgrades  # parches automáticos
# Firewall interno: reglas listas, SIN activar (ver GUIA.md).
ufw allow OpenSSH
ufw allow 'Nginx Full'

# ---- 5. Node.js 22 + pnpm + PM2 ----
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs
npm install -g pnpm@11.24.0 pm2
# PM2 arranca la app sola cuando el servidor reinicia.
pm2 startup systemd -u "$APP_USER" --hp /home/$APP_USER

# ---- 6. Nginx: puerta de entrada (80) -> app (3000) ----
cat > /etc/nginx/sites-available/lab <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
ln -sf /etc/nginx/sites-available/lab /etc/nginx/sites-enabled/lab
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable nginx
systemctl restart nginx

# ---- 7. Respaldo diario (cron, guarda 7 días) ----
cat > /etc/cron.daily/lab-backup <<'EOF'
#!/bin/bash
mkdir -p /var/backups/lab
tar czf /var/backups/lab/lab-$(date +%F).tar.gz \
  /home/deploy/servidorprueba /etc/nginx/sites-available
find /var/backups/lab -name '*.tar.gz' -mtime +7 -delete
EOF
chmod +x /etc/cron.daily/lab-backup

# ---- 8. Montar la app COMO USUARIO deploy ----
if [ ! -d /home/$APP_USER/servidorprueba ]; then
  sudo -iu "$APP_USER" git clone "$REPO" servidorprueba
fi
sudo -iu "$APP_USER" bash servidorprueba/2-deploy.sh

echo "LISTO: abre http://$(curl -s https://checkip.amazonaws.com)"
