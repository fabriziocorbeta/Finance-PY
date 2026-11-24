---
name: financepy-prod-deploy
description: >-
  Runbook for Finance-PY local environment constraints, protected main PR workflow,
  and SSH/Docker deployment to the production notebook server (fabrizio@100.105.31.71).
  Use when running Rails tests, pushing changes to GitHub, or deploying to production.
---

# Finance-PY: Entorno, PRs y Despliegue a Producción

## 1. Limitación del entorno local (Mac)
- Este Mac solo dispone del Ruby del sistema (`2.6.10`, sin Homebrew, `rbenv`, `mise` ni `docker`).
- No intentar correr `bin/rails test` o `bundle` en local si falla por versión de Ruby (`Gemfile` requiere Ruby `3.4.7`); validar sintaxis con `ruby -c` y delegar la suite completa a GitHub Actions mediante PR.

## 2. Subir cambios (rama `main` protegida)
`main` rechaza pushes directos (`GH006: Protected branch update failed`). Todo cambio debe ir por PR:

1. Si el working tree tiene cambios no relacionados, aislar el commit en un worktree limpio:
   ```zsh
   git worktree add --detach /tmp/financepy-pr origin/main
   (cd /tmp/financepy-pr && git cherry-pick <COMMIT_SHA> && git push origin HEAD:refs/heads/<nombre-rama>)
   git worktree remove /tmp/financepy-pr
   ```
2. Abrir y mergear el PR en GitHub (`https://github.com/fabriziocorbeta/Finance-PY/pull/new/<nombre-rama>`).
3. Esperar a que `Build and push to GHCR` termine tras el merge.

## 3. Conexión SSH y despliegue en servidor
- **Host Tailscale**: `ssh fabrizio@100.105.31.71` (clave `~/.ssh/id_ed25519`).
- **Directorio del repo**: `~/financespy`
- **Compose activo**: `compose.local.yml` con `.env.local` (NO usar `compose.prod.yml`).
- Si SSH pide passphrase en modo no interactivo, pedir al usuario ejecutar `ssh-add ~/.ssh/id_ed25519` en su terminal.
- Para desplegar tras el merge a `main`, ejecutar explícitamente con `bash`:
  ```zsh
  ssh -o BatchMode=yes fabrizio@100.105.31.71 "cd ~/financespy && bash ./bin/deploy_notebook.sh"
  ```
- Verificar que el script termine con `GET /up returned 200 OK`.
