# Demo: servidor en la nube que se arma solo

## Flujo (qué y por qué)
1. **Next.js + pnpm** (`app/`): app web moderna; pnpm = instalador rápido y ligero.
2. **GitHub**: guarda el código. El servidor lo descarga con `git clone` → el repo es la "fuente de verdad".
3. **`bootstrap.sh`**: script de arranque de Lightsail. Instala y configura TODO (usuarios, seguridad, nginx, HTTPS, respaldo).
4. **Dominio gratis**: apunta un registro DNS `A` a la IP estática del servidor.

## Dominios gratis (repos con más estrellas, verificado con GitHub el 2026-11-05)
| Repo | Estrellas | Nota |
|---|---|---|
| dnshe/DNSHE-FreeDomains | ~22 mil | subdominios us.ci, cc.cd… con API |
| open-domains/register | ~2.6 mil | PR con un JSON; fusión de free-domains |
| is-cool-me/register | ~760 | mismo modelo (PR) |
| Pokymon/foo.ng | ~330 | activo |
**Elegido: DNSHE** — cuenta gratis en https://my.dnshe.com, eliges prefijo + sufijo (ej. `miapp.de5.net`) y agregas el registro A desde el panel. Es lo más fácil: sin Pull Request ni espera. Nota: `open-domains/register` ya no se gestiona por GitHub (migró a open-domains.com).

## Pasos
1. Subir a GitHub (`gh repo create servidorprueba --public --source . --push`).
2. Lightsail: crear instancia Ubuntu 2 GB, pegar `bootstrap.sh` en "Launch script", asignar **IP estática**.
3. Firewall de Lightsail: abrir 22, 80, 443.
4. Registrar el dominio en DNSHE (registro A → IP estática); si el certbot falló, correrlo a mano.
5. Respaldo: activar snapshots automáticos en la consola de Lightsail.
