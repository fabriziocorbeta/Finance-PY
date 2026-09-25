# Procedimiento Operativo: Rotación de Claves de Cifrado

Este documento detalla el procedimiento para rotar las claves criptográficas de **Finance-PY** sin tiempo de inactividad ni pérdida de acceso a datos o archivos preexistentes.

---

## 1. Arquitectura de Cifrado Multiclave

Active Record Encryption y el servicio de almacenamiento de archivos (`ActiveStorage::Service::EncryptedDiskService`) soportan rotación mediante arrays de claves:
* **Clave activa (escritura):** La primera clave provista en la lista. Todo dato o archivo nuevo se cifra con esta clave.
* **Claves anteriores (lectura):** Las claves secundarias separadas por coma en las variables de entorno. Permiten desencriptar datos y archivos históricos transparentemente.

---

## 2. Variables de Entorno
En producción, se configuran en el archivo `.env` o gestor de secretos:
```env
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY="<clave_nueva>,<clave_anterior>"
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY="<clave_nueva>,<clave_anterior>"
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT="<sal_nueva>,<sal_anterior>"
```

---

## 3. Pasos para la Rotación
1. **Generación de nuevas claves:**
   ```bash
   bin/rails db:encryption:init
   ```
2. **Actualización de variables de entorno:**
   - Prependé las nuevas claves generadas a las existentes, separadas por coma `,`.
3. **Reinicio de la aplicación:**
   ```bash
   docker compose restart web worker
   ```
4. **Verificación de compatibilidad:**
   - Verificá que los registros existentes sean legibles desde la UI/API.
   - Ejecutá la tarea de conteo de datos no cifrados:
     ```bash
     bin/rails security:verify_unencrypted
     ```
5. **(Opcional) Re-cifrado de datos y archivos existentes con la clave activa:**
   ```bash
   bin/rails storage:encrypt_existing
   ```
