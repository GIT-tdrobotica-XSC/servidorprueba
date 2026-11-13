# Laboratorio: servidor en la nube que se arma solo

Next.js + pnpm → GitHub → Lightsail (Ubuntu 24.04) → dominio con HTTPS.

**Guía completa para montarlo y explicarlo: [`GUIA.md`](GUIA.md).**

| Archivo | Qué es |
|---|---|
| `1-launch.sh` | Prepara Ubuntu como root y llama a `2-deploy.sh`. En el *Launch script* de Lightsail solo se pegan 2 líneas: `git clone https://github.com/GIT-tdrobotica-XSC/servidorprueba /opt/lab` y `bash /opt/lab/1-launch.sh`. |
| `2-deploy.sh` | Como usuario `deploy`: trae el repo, compila y arranca la app. Sirve para actualizar. |
| `3-https.sh` | Conecta el dominio y saca el certificado HTTPS. |
| `verificar.sh` | Comprueba dentro de Ubuntu que todo quedó bien (`[OK]` / `[FALLA]`). |
| `app/` | App Next.js (pnpm). |

## Dominio gratis
[DNSHE](https://github.com/dnshe/DNSHE-FreeDomains) (el repo de dominios gratis con más estrellas en GitHub):
cuenta en https://my.dnshe.com → elegir nombre → registro **A** a la IP estática.
