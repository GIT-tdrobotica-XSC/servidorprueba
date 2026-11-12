# Guía del laboratorio — Servidor en la nube que se arma solo

## La idea en una frase
Un servidor Ubuntu **vacío** se convierte solo en un sitio web con dominio y HTTPS,
usando **código guardado en GitHub**. Si se daña, se crea otro igual en 10 minutos.

```
 Mi PC                GitHub                Lightsail (Ubuntu 24.04)                Internet
 Next.js + pnpm ──▶   repositorio  ──▶  1-launch.sh (root)  → prepara Ubuntu
   git push           (fuente de        2-deploy.sh (deploy) → baja y monta la app
                       verdad)          3-https.sh  (root)  → dominio + HTTPS  ──▶ https://demomateria.us.ci
```

## Los 3 scripts
| Script | Lo corre | Cuándo | Qué hace |
|---|---|---|---|
| `1-launch.sh` | **root** (Lightsail) | Solo al **crear** la instancia | Prepara Ubuntu: swap, updates, usuario `deploy`, seguridad, Node/pnpm/PM2, nginx, respaldo. Al final llama a `2-deploy.sh`. |
| `2-deploy.sh` | **deploy** (usuario normal) | La 1ª vez (automático) y **cada vez que hay cambios** | `git clone/pull` → `pnpm install` → `pnpm build` → PM2 arranca/recarga la app. |
| `3-https.sh` | **root** (a mano) | Cuando el dominio ya apunta a la IP | Pone el dominio en nginx y saca el certificado HTTPS gratis. |

**¿Por qué separarlos?**
- Lo que necesita root (instalar, configurar el sistema) va aparte de la app → **mínimo privilegio**.
- `2-deploy.sh` se reutiliza para **actualizar** la app sin rehacer el servidor.
- El HTTPS depende del DNS, que tarda en propagarse; separado, nunca rompe el lanzamiento.

## Montaje (orden exacto)
1. **Lightsail → Create instance** → Linux/Unix → *OS Only* → **Ubuntu 24.04 LTS** → plan **2 GB**.
2. **Add launch script**: abre en el navegador
   <https://raw.githubusercontent.com/GIT-tdrobotica-XSC/servidorprueba/master/1-launch.sh>,
   `Ctrl+A`, `Ctrl+C` y pégalo **completo** en la caja. *(Copiar desde el navegador, no desde
   la terminal: la terminal parte las líneas largas y rompe el script.)*
3. **Create instance**. Mientras arranca:
   - Networking → **Create static IP** → asociarla a la instancia.
   - Firewall IPv4: **SSH 22, HTTP 80, HTTPS 443** (el 443 hay que añadirlo).
   - DNSHE (my.dnshe.com) → registro **A** del dominio = la IP estática.
4. **Esperar ~8–10 min**. Ver el avance: *Connect using SSH* →
   `sudo tail -f /var/log/lab.log` (termina con `LISTO`).
5. Abrir `http://IP_ESTATICA` → ya se ve la app.
6. HTTPS: `sudo bash /home/deploy/servidorprueba/3-https.sh demomateria.us.ci`
7. Comprobar todo: `sudo bash /home/deploy/servidorprueba/verificar.sh demomateria.us.ci`
8. Snapshots → **Enable automatic snapshots** (respaldo de AWS).

> **Truco para la clase:** crea la instancia al **empezar** la presentación. Explicas los
> scripts mientras se instala, y a los 10 minutos muestras el resultado.

## Qué hace `1-launch.sh` dentro de Ubuntu
| # | Paso | Por qué | Cómo demostrarlo |
|---|---|---|---|
| 1 | Swap de 2 GB | Compilar Next.js gasta mucha RAM | `free -h` |
| 2 | `apt upgrade` + paquetes | Parches de seguridad + herramientas | `apt list --upgradable` |
| 3 | Usuario `deploy` con sudo | La app nunca corre como root | `id deploy` |
| 4 | SSH sin root ni contraseña, fail2ban, parches automáticos | Defensa contra fuerza bruta | `sudo sshd -T \| grep -E 'rootlogin\|passwordauth'` · `sudo fail2ban-client status sshd` |
| 5 | Node 22, pnpm, PM2 | Ejecutar y mantener viva la app | `node -v; pnpm -v; pm2 -v` |
| 6 | Nginx: 80 → 3000 | *Proxy inverso*: nginx es la recepción, la app la oficina interna | `cat /etc/nginx/sites-available/lab` |
| 7 | Respaldo diario (cron, 7 días) | Copia de la app y la config | `sudo /etc/cron.daily/lab-backup; ls /var/backups/lab` |
| 8 | Corre `2-deploy.sh` como `deploy` | Montar la app con un usuario sin privilegios | `sudo -iu deploy pm2 status` |

**Firewall:** hay dos capas. La que protege es la de **Lightsail** (fuera del servidor).
`ufw` (dentro de Ubuntu) queda con reglas escritas pero **sin activar** a propósito:
activarlo desde el script de lanzamiento puede colgar el arranque o dejar SSH bloqueado
tras un reinicio. Si se quiere activar: sacar un snapshot y luego `sudo ufw enable`.

## Demo estrella: actualizar la app con un `git push`
1. En el PC, cambia el texto de `app/app/page.tsx` → `git commit -am "cambio"` → `git push`.
2. En el servidor: `sudo -iu deploy bash servidorprueba/2-deploy.sh`
3. Refresca el navegador: el cambio está en vivo.

Esto es un **despliegue continuo** manual. El siguiente paso (para mencionar, no hace falta
montarlo) sería que GitHub Actions corra ese mismo comando por SSH en cada push.

## Comandos de prueba (cortos, para copiar)
```
sudo bash /home/deploy/servidorprueba/verificar.sh   # todo en uno
sudo tail -40 /var/log/lab.log                       # qué hizo el lanzamiento
sudo -iu deploy pm2 status                           # ¿vive la app?
sudo -iu deploy pm2 logs web --lines 20              # logs de la app
sudo -iu deploy pm2 restart web                      # PM2 la reinicia
systemctl status nginx --no-pager                    # ¿vive nginx?
sudo tail -5 /var/log/nginx/access.log               # visitas reales
sudo fail2ban-client status sshd                     # IPs bloqueadas
sudo certbot certificates                            # vencimiento HTTPS
curl -I localhost:3000                               # la app por dentro
```

## Problemas vistos durante la preparación
| Problema | Causa | Solución |
|---|---|---|
| El script no corrió / se rompió al pegarlo | Copiado desde la terminal, que parte líneas largas | Copiar desde GitHub *raw* en el navegador |
| Fallaba todo con `apt-get: not found` | Instancia creada con **Amazon Linux** | Usar **Ubuntu 24.04** |
| `libatomic.so.1: cannot open shared object` | pnpm 11 necesita esa librería | `libatomic1` en el paso 2 |
| Servidor muy lento al compilar | Sin swap, se agota la RAM | Paso 1: swap |
| Certbot falla | DNS aún no apunta o 443 cerrado | `3-https.sh` va aparte y revisa el DNS antes |
| Dominio sin respuesta tras recrear la instancia | La IP cambió | IP estática y reasociarla |

## Checklist del día
- [ ] Ensayo completo con una instancia nueva antes de la clase.
- [ ] Registro A en DNSHE = IP estática.
- [ ] Puertos 22, 80, 443 en Lightsail.
- [ ] No reiniciar el servidor sin snapshot previo.
- [ ] Al terminar: borrar la instancia y **liberar la IP estática** (sin asociar, se cobra).

## Fuentes (buenas prácticas)
- AWS: [Create, use, and troubleshoot launch scripts on Amazon Lightsail](https://aws.amazon.com/blogs/compute/create-use-and-troubleshoot-launch-scripts-on-amazon-lightsail) — el script corre como root una sola vez; log en `/var/log/cloud-init-output.log`.
- [Lightsail launch script breaks instance (re:Post)](https://www.repost.aws/questions/QUiYjfZVYlTK-NoPQJ9KfVZw/lightsail-launch-script-breaks-instance)
