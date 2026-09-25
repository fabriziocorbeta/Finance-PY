# Bot Workflow & Safeguards Guide

Esta guía documenta las mejores prácticas y restricciones para agentes autónomos y bots (ej. Jules, Claude, Antigravity) que colaboran en el repositorio **Finance-PY**.

---

## 1. Convención de Ramas
* Todo bot o agente debe trabajar exclusivamente en ramas con prefijo dedicado:
  - `jules/*`
  - `claude/*`
  - `security/*` o `feat/*` según el plan de trabajo acordado.
* **Prohibido:** Hacer push directo a la rama `main` o a ramas personales de otros desarrolladores sin previa revisión.

---

## 2. Archivos Críticos Protegidos
Para prevenir rupturas de infraestructura, dependencias o permisos:
* Los bots **NUNCA** deben modificar ni sobreescribir de forma no supervisada:
  - `.github/workflows/**` (Pipelines de CI/CD).
  - `Gemfile` y `Gemfile.lock` (salvo tareas explícitas de actualización de dependencias con bundler-audit).
  - `config/environments/production.rb` o variables secretas.

---

## 3. Verificación de Base de Rama (Evitar Pisado de Fixes)
> **Lección aprendida:** Los bots no deben iniciar trabajo desde una base desactualizada de `main` ni hacer `git push --force` sobre ramas compartidas.

Antes de comenzar y antes de abrir un PR:
```bash
git fetch origin main
git rebase origin/main
```
Asegurarse de que el historial sea lineal y compatible con las migraciones y el esquema actual (`structure.sql`).

---

## 4. Firma Criptográfica de Commits (SSH / GPG)
Se recomienda que los commits sean firmados:
1. Generar una clave SSH para firmas:
   ```bash
   ssh-keygen -t ed25519 -C "bot@finance-py"
   ```
2. Configurar Git:
   ```bash
   git config gpg.format ssh
   git config user.signingkey ~/.ssh/id_ed25519.pub
   git config commit.gpgsign true
   ```
3. Agregar la clave pública SSH en GitHub (Settings -> SSH and GPG keys -> New Signing Key).

---

## 5. Prevención de Pushes a Repositorios Redirigidos o Desactualizados
El hook en `bin/git-hooks/pre-push` aborta automáticamente cualquier intento de push cuyo destino no coincida con `github.com/fabriziocorbeta/Finance-PY`. Para activarlo en un clon local:
```bash
./bin/setup-git-hooks
```
