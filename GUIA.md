# Guía para explicar el laboratorio (Ubuntu en Lightsail)

## La idea en una frase
Con **un repositorio en GitHub** y **un script de arranque**, un servidor vacío se convierte
solo en un sitio web con dominio, HTTPS, seguridad y respaldo. Si se daña, se crea otro igual.

```
 Tu PC ──push──▶ GitHub ──git clone──▶ Lightsail (Ubuntu) ──nginx──▶ https://demomateria.us.ci
 (Next.js+pnpm)  (fuente de verdad)    (bootstrap.sh)         ▲
                                                     DNSHE: registro A → IP estática
```

## Montaje en vivo (orden exacto)
1. **Lightsail → Create instance**: Linux/Unix, *OS Only*, **Ubuntu 24.04 LTS**, plan **2 GB**.
2. **Launch script** (pegar exactamente estas 4 líneas, son cortas a propósito):
   ```
   #!/bin/bash
   cd /opt
   git clone https://github.com/GIT-tdrobotica-XSC/servidorprueba
   bash /opt/servidorprueba/bootstrap.sh
   ```
3. Crear la instancia. Networking → **Create static IP** y asociarla a la instancia.
4. Firewall IPv4 de la instancia: **22, 80 y 443** (el 443 no viene por defecto).
5. DNSHE (my.dnshe.com) → dominio → registro **A** = la IP estática.
6. Esperar ~10 min. Ver el avance entrando por SSH ("Connect using SSH"):
   `sudo tail -f /var/log/bootstrap.log` — termina con `LISTO: https://...`.
7. Abrir el dominio en el navegador. Luego, dentro de Ubuntu:
   `sudo bash /opt/servidorprueba/verificar.sh`
8. Activar **snapshots automáticos** en la pestaña Snapshots (respaldo del lado de AWS).

> Si cambias de dominio: edita la variable `DOMAIN` al inicio de `bootstrap.sh`, haz push
> y crea la instancia de nuevo.

## Qué hace el script, paso a paso (y cómo demostrarlo dentro de Ubuntu)

| Paso | Qué hace | Por qué | Cómo probarlo |
|---|---|---|---|
| 0 | Crea **swap** de 2 GB | Compilar Next.js gasta mucha RAM; el swap usa disco como RAM de emergencia | `free -h` |
| 1 | `apt update/upgrade` + instala nginx, git, fail2ban, certbot… | Parches de seguridad al día y herramientas | `lsb_release -a` · `apt list --upgradable` |
| 2 | Crea el usuario **deploy** con sudo | Nunca ejecutar la app como root: si la hackean, el daño es limitado | `id deploy` |
| 3 | SSH sin root ni contraseña; **fail2ban**; actualizaciones automáticas; reglas de **ufw** | Defensa en capas contra fuerza bruta | `sudo sshd -T \| grep -E "rootlogin\|passwordauth"` · `sudo fail2ban-client status sshd` · `sudo ufw status` |
| 4 | Instala **Node 22, pnpm, PM2** (+ `libatomic1`) | Node ejecuta Next.js; pnpm instala dependencias; PM2 mantiene la app viva | `node -v` · `pnpm -v` · `pm2 -v` |
| 5 | **Clona el repo**, `pnpm install`, `pnpm build`, `pm2 start` | La app sale de GitHub, no se copia a mano | `sudo -u deploy pm2 status` · `curl localhost:3000` |
| 6 | **Nginx** como proxy inverso | La app escucha en el 3000 (interno); nginx atiende 80/443 y reenvía | `sudo nginx -t` · `cat /etc/nginx/sites-available/app` |
| 7 | **Certbot** (Let's Encrypt) | HTTPS gratis y renovación automática | `sudo certbot certificates` · `curl -I https://TUDOMINIO` |
| 8 | **Respaldo** diario en cron (7 días) | Copia local de la app y la config de nginx | `sudo /etc/cron.daily/backup-app; ls -lh /var/backups/app` |

### Conceptos para decir en voz alta
- **Proxy inverso**: nginx es la "recepción" del edificio; la app es la oficina interna.
- **Puerto 3000 vs 443**: el 3000 nunca se expone a internet; solo nginx.
- **Dos firewalls**: el de **Lightsail** (capa AWS, el que realmente protege) y **ufw** (dentro de
  Ubuntu). ufw queda con reglas escritas pero **sin activar**: activarlo en el launch script
  cuelga cloud-init y tras un reboot puede dejar SSH bloqueado. Si se activa, hacerlo a mano
  y con un snapshot previo: `sudo ufw enable`.
- **Idempotente**: el script se puede volver a correr sin romper nada (`sudo bash bootstrap.sh`).
- **Infraestructura como código**: el servidor es reproducible porque todo está en el repo.

## Comandos de prueba dentro de Ubuntu (todos cortos, para copiar)
```
sudo bash /opt/servidorprueba/verificar.sh    # todo en uno, con [OK]/[FALLA]
sudo tail -50 /var/log/bootstrap.log          # qué hizo el script
sudo -u deploy pm2 status                     # ¿vive la app?
sudo -u deploy pm2 logs web --lines 20        # logs de la app
sudo systemctl status nginx --no-pager        # ¿vive nginx?
sudo tail -20 /var/log/nginx/access.log       # visitas reales
sudo ufw status verbose                       # reglas del firewall interno
sudo fail2ban-client status sshd              # IPs baneadas
sudo certbot certificates                     # vencimiento del HTTPS
df -h /                                       # espacio en disco
```
Matar la app para mostrar que PM2 la revive: `sudo -u deploy pm2 restart web`.

## Lo que falló durante la preparación (útil para mostrar criterio)
| Problema | Causa | Solución |
|---|---|---|
| El script no corrió | Pegado con saltos de línea / instancia Amazon Linux | Launch script de 4 líneas cortas + **Ubuntu** (el script usa `apt`) |
| `libatomic.so.1: cannot open shared object` | pnpm 11 es un binario que necesita esa librería | `apt-get install libatomic1` (ya está en el script) |
| Servidor muy lento al compilar | Sin swap, se agota la RAM | Paso 0: swap de 2 GB |
| Certbot falla | El DNS aún no apunta a la IP, o el 443 está cerrado | Abrir 443; verificar `nslookup`; `sudo certbot --nginx -d TUDOMINIO` |
| El dominio no responde tras recrear la instancia | La IP cambió y el registro A quedó viejo | Usar **IP estática** y reasociarla |

## Antes del día de la entrega
- [ ] Hacer un ensayo completo con una instancia nueva (debe llegar a `LISTO` sin pasos manuales).
- [ ] Registro A en DNSHE apuntando a la IP estática correcta.
- [ ] Puertos 22, 80, 443 abiertos en Lightsail.
- [ ] Snapshots automáticos activados.
- [ ] **No reiniciar** el servidor sin sacar un snapshot primero.
- [ ] Al terminar: borrar la instancia y **liberar la IP estática** (si queda sin asociar, se cobra).
- [ ] Renovar el dominio en DNSHE si lo pide (renovación gratis hasta 180 días antes del vencimiento).
