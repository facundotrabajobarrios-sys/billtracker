# Guía: migrar BillTracker a un proyecto Supabase nuevo

Esta guía migra BillTracker a un **proyecto Supabase nuevo** para poder
presentarlo y ejecutarlo en Android, iOS, web y Windows. Usa el backup manual
que contiene `database-public.dump` y `edge-functions/`.

> **Importante:** el dump actual contiene objetos y datos del esquema `public`,
> pero no contiene usuarios de Supabase Auth, archivos de Storage, secretos,
> Cron/Vault ni configuración del proyecto. Para una defensa o demo nueva, lo
> más sencillo es restaurar solo el esquema y crear una cuenta y datos de
> demostración nuevos. Para conservar los datos vinculados a usuarios, consulta
> primero la sección “Si necesitas conservar usuarios y sus datos”.

## 1. Crear el proyecto Supabase nuevo

1. Crea un proyecto en el Dashboard de Supabase y guarda la contraseña de la
   base de datos en un gestor seguro.
2. Espera a que termine el aprovisionamiento.
3. En **Project Settings → API** copia el Project URL y la clave publicable
   (`sb_publishable_...`) o anon key. Son valores que puede usar Flutter.
4. En **Project Settings → Database** copia la cadena de conexión PostgreSQL
   del pooler. Reemplaza el marcador de contraseña y guárdala solo en `.env`.
5. Copia el backup a una ubicación segura fuera del repositorio. La carpeta
   `backups/` está excluida de Git y no se sube con `git push`.

No uses la clave `service_role` en Flutter, en la web, en `.env` compartido ni
en GitHub. Esa clave omite RLS y debe permanecer en Supabase.

## 2. Elegir cómo restaurar

### Opción recomendada para una demo nueva: esquema sin datos

Esta opción conserva las tablas, políticas, funciones y triggers públicos, pero
no importa facturas ni referencias a las cuentas viejas.

Desde PowerShell, usando `pg_restore` 17 o posterior:

```powershell
pg_restore `
  --schema-only `
  --no-owner `
  --no-acl `
  --schema=public `
  --dbname="NUEVA_DATABASE_URL" `
  "RUTA\AL\BACKUP\database-public.dump"
```

Sustituye `NUEVA_DATABASE_URL` y la ruta por los datos reales. Evita pegar una
contraseña en capturas, chats o archivos versionados. Después crea una cuenta
nueva en la aplicación y agrega facturas de prueba.

### Si necesitas conservar los datos existentes

El dump normal incluye filas cuyo `user_id` apunta a UUID de `auth.users`, pero
no exporta esas cuentas ni sus contraseñas. Si restauras el dump completo sin
migrar primero las identidades, la creación de las claves foráneas puede fallar
o los usuarios existentes no podrán iniciar sesión.

Antes de restaurar datos, utiliza un procedimiento de migración de usuarios
compatible con Supabase Auth que conserve los UUID originales y verifica que
las identidades estén en el nuevo proyecto. No copies directamente tablas
internas de `auth` entre proyectos. Luego restaura el dump completo:

```powershell
pg_restore `
  --no-owner `
  --no-acl `
  --schema=public `
  --dbname="NUEVA_DATABASE_URL" `
  "RUTA\AL\BACKUP\database-public.dump"
```

Prueba primero en un proyecto desechable y conserva el backup original. No uses
`--clean` en producción: puede eliminar objetos existentes.

## 3. Enlazar la CLI y aplicar las migraciones

Desde la raíz del repositorio:

```powershell
npx supabase login
npx supabase link --project-ref NUEVO_PROJECT_REF
```

Antes de ejecutar `db push`, abre
`supabase/migrations/202609300001_bill_notification_channels.sql` y cambia el
host de la llamada Cron del proyecto anterior:

```text
https://zvvvkkekxlokpajrpggv.supabase.co/functions/v1/send-bill-reminders
```

por:

```text
https://NUEVO_PROJECT_REF.supabase.co/functions/v1/send-bill-reminders
```

En el Dashboard nuevo, encuentra la clave `service_role` del proyecto en
**Project Settings → API**. En **Database → Vault → Secrets**, crea un secreto
con nombre exacto:

```text
billtracker_service_role_key
```

Guarda ahí el valor `service_role` del **proyecto nuevo**, nunca el del antiguo.
La migración `202609300001_bill_notification_channels.sql` requiere ese secreto
y crea/actualiza el Cron que llama la función cada minuto.

Después aplica las migraciones:

```powershell
npx supabase db push
```

El dump ya puede contener objetos del esquema; las migraciones del repositorio
usan operaciones idempotentes para las tablas y columnas principales. Si la CLI
informa una migración ya aplicada o un conflicto, detente y compara el historial
con el esquema restaurado; no borres tablas ni uses `db reset` en el proyecto
nuevo con datos.

## 4. Configurar Auth y URLs

En **Authentication → URL Configuration**:

- Site URL:
  `https://facundotrabajobarrios-sys.github.io/billtracker/`
- Redirect URLs permitidas:
  - `https://facundotrabajobarrios-sys.github.io/billtracker/auth/callback`
  - `https://facundotrabajobarrios-sys.github.io/billtracker/auth/reset-password`
  - `miapp://auth-callback`
  - `http://localhost:3000`

En **Authentication → Providers → Email**, activa la confirmación de correo.
Si quieres enviar correos de autenticación a usuarios reales, configura también
un SMTP válido en Supabase Auth; el secreto Resend de las Edge Functions no
configura por sí solo el SMTP de Auth.

En **Authentication → Email Templates**, configura los enlaces para que la app
pueda validarlos aunque el usuario abra el correo en otro navegador o
dispositivo. En **Confirm signup**, usa un enlace con el token hash:

```html
<a href="https://facundotrabajobarrios-sys.github.io/billtracker/auth/callback?token_hash={{ .TokenHash }}&type=signup">
  Confirmar correo
</a>
```

En **Reset password**, usa:

```html
<a href="https://facundotrabajobarrios-sys.github.io/billtracker/auth/reset-password?token_hash={{ .TokenHash }}&type=recovery">
  Cambiar contraseña
</a>
```

Los dos destinos deben permanecer en la lista de Redirect URLs permitidas.
Los enlaces son de un solo uso y caducan según el tiempo configurado en Auth;
si un enlace vence o ya se utilizó, solicita uno nuevo.

## 5. Desplegar las Edge Functions y configurar secretos

Las fuentes están en `supabase/functions/` y la copia del backup en
`edge-functions/`. Desde la raíz del proyecto despliega:

```powershell
npx supabase functions deploy delete-account --use-api
npx supabase functions deploy send-bill-reminders --use-api
npx supabase functions deploy send-test-notification --use-api
```

En **Edge Functions → Secrets** del nuevo proyecto configura:

- `RESEND_API_KEY`: clave del proveedor de correo.
- `MAIL_FROM`: remitente verificado, por ejemplo `BillTracker <no-reply@tu-dominio.com>`.

Supabase proporciona a las funciones sus variables internas de proyecto, entre
ellas `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY`. No las copies desde el
proyecto anterior. Nunca guardes estas claves en Flutter, GitHub Pages ni en
archivos de backup.

Si prefieres la CLI, desde PowerShell:

```powershell
npx supabase secrets set RESEND_API_KEY="CLAVE_RESEND"
npx supabase secrets set MAIL_FROM="BillTracker <no-reply@tu-dominio.com>"
```

Configura un dominio remitente verificado en Resend para correos a destinatarios
reales; el remitente de prueba puede tener restricciones.

## 6. Verificar el Cron y las notificaciones

La migración crea el Cron `bill-reminders-every-minute`. Compruébalo en
**Integrations → Cron Jobs** o ejecuta:

```sql
select jobid, jobname, schedule, active
from cron.job
where jobname = 'bill-reminders-every-minute';
```

Debe estar activo y ejecutar cada minuto (`* * * * *`). Revisa el historial de
ejecuciones y los logs de `send-bill-reminders` después de crear una factura
pendiente con un recordatorio próximo.

- Correo: revisa los logs de Resend, bandeja de entrada y Spam.
- Bandeja interna: consulta `public.notifications`.
- Android/iOS: concede permisos; son notificaciones locales del dispositivo.
- Web: muestra la bandeja interna, pero no implementa push del navegador.

## 7. Cambiar las credenciales públicas en Flutter

En `lib/config/supabase_config.dart`, sustituye `url` y `anonKey` por el Project
URL y la clave publicable/anon del proyecto nuevo. No coloques ahí una clave
`service_role`, una contraseña PostgreSQL ni una clave secreta de Resend.

Actualiza los valores de configuración del proyecto para ese entorno y compila
la plataforma que vas a probar. Por ejemplo:

```powershell
flutter pub get
flutter analyze
flutter run -d chrome
```

Para publicar GitHub Pages:

```powershell
flutter build web --release --base-href /billtracker/ -o docs
```

Luego publica `docs/` según el flujo GitHub Pages del repositorio. Android e
iOS conservan el esquema de callback `miapp://auth-callback`; comprueba que las
URLs estén permitidas en Auth y que la app instalada tenga los deep links
configurados.

Requisitos de ejecución:

- Android: Android SDK y permisos de notificación/alarmas.
- iOS: macOS con Xcode para compilar e instalar.
- Web: navegador compatible y despliegue actualizado.
- Windows: Visual Studio con la carga de trabajo **Desktop development with C++**.

## 8. Prueba final antes de la defensa

1. Registra una cuenta nueva y confirma el correo.
2. Inicia sesión y comprueba que puede acceder a sus pantallas.
3. Crea una factura pendiente con una fecha/hora de prueba próxima.
4. Verifica los logs de Cron y `send-bill-reminders`.
5. Confirma la fila en `bill_reminder_deliveries` y la notificación en
   `public.notifications`.
6. Comprueba el correo y, en un móvil con permisos, la notificación local.
7. Prueba recuperación de contraseña y eliminación de cuenta si forman parte de
   la demostración.

## Qué no migra este procedimiento

- Usuarios, credenciales y sesiones de Supabase Auth.
- Objetos de Supabase Storage.
- Secretos de Edge Functions o Vault.
- Configuración del proyecto, proveedor SMTP y dominios verificados.
- Cron/Vault del proyecto antiguo; el Cron de esta guía se recrea mediante la
  migración.
- Tokens de notificación o configuración externa de Firebase/APNs.

Conserva las claves y contraseñas en un gestor seguro y guarda una copia del
backup fuera del equipo. No subas la carpeta `backups/` al repositorio.
