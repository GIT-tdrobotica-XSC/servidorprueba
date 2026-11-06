# Demo: servidor en la nube que se arma solo

Next.js + pnpm → GitHub → script de arranque en Lightsail (Ubuntu 24.04) → dominio con HTTPS.

**Para explicarlo y montarlo: ver [`GUIA.md`](GUIA.md).**

## Archivos
| Archivo | Para qué sirve |
|---|---|
| `app/` | App Next.js (pnpm). Una página simple. |
| `bootstrap.sh` | Script de arranque: configura TODO el servidor Ubuntu (comentado paso a paso). |
| `verificar.sh` | Se corre dentro de Ubuntu y comprueba que cada parte quedó bien. |
| `GUIA.md` | Guion de la clase: montaje, qué hace cada paso, comandos de prueba, problemas vistos. |

## Launch script de Lightsail (4 líneas, a propósito cortas)
```
#!/bin/bash
cd /opt
git clone https://github.com/GIT-tdrobotica-XSC/servidorprueba
bash /opt/servidorprueba/bootstrap.sh
```

## Dominio gratis
Se usó [DNSHE](https://github.com/dnshe/DNSHE-FreeDomains) (~22 mil estrellas en GitHub, consultado 2026-11-05):
cuenta gratis en https://my.dnshe.com, se elige prefijo + sufijo y se agrega un registro **A** a la IP estática.
Otros repos revisados: `is-cool-me/register`, `Pokymon/foo.ng`. `open-domains/register` ya no se gestiona por GitHub.
