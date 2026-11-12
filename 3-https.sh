#!/bin/bash
# =====================================================================
# 3-https.sh — conecta el DOMINIO y activa HTTPS (Let's Encrypt)
#
# CUÁNDO: cuando el registro A del dominio ya apunta a la IP estática.
# USO:    sudo bash /home/deploy/servidorprueba/3-https.sh midominio.us.ci
# =====================================================================
set -euo pipefail
DOMAIN="${1:?Uso: sudo bash 3-https.sh midominio.com}"

echo "== 1. ¿El dominio apunta a este servidor?"
MI_IP="$(curl -s https://checkip.amazonaws.com)"
DNS_IP="$(getent ahostsv4 "$DOMAIN" | awk 'NR==1{print $1}')"
echo "   IP del servidor: $MI_IP   |   DNS de $DOMAIN: ${DNS_IP:-no resuelve}"
if [ "$MI_IP" != "$DNS_IP" ]; then
  echo "   Aún no. Corrige el registro A en DNSHE y espera unos minutos."
  exit 1
fi

echo "== 2. Nginx responde por ese nombre"
sed -i "s/server_name .*;/server_name $DOMAIN;/" /etc/nginx/sites-available/lab
nginx -t
systemctl reload nginx

echo "== 3. Certificado gratis + redirección a HTTPS"
certbot --nginx -d "$DOMAIN" --redirect --agree-tos \
  --register-unsafely-without-email -n

echo "LISTO: https://$DOMAIN"
