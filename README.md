# BillTracker

BillTracker es una aplicación multiplataforma desarrollada con Flutter para
registrar facturas personales, controlar vencimientos, recibir recordatorios y
consultar el comportamiento de los gastos.

## Funcionalidades

- Registro, inicio de sesión, confirmación de correo y recuperación de contraseña.
- Gestión de facturas: alta, edición, eliminación, filtros y estados pendiente,
  pagada y vencida.
- Recordatorios configurables por factura: push local en móvil, correo e inbox.
- Panel con resúmenes, gráficos y exportación a PDF o CSV.
- Puntos, niveles e insignias por pagos realizados a tiempo.
- Eliminación de cuenta desde la aplicación.
- Registro de auditoría por usuario en `public.audit_logs`.

La aplicación utiliza un único perfil funcional: usuario final. No se implementan
roles administrativos ni perfiles alternativos.

## Arquitectura

- `lib/screens`: pantallas de Flutter.
- `lib/providers`: estado de autenticación, facturas, gamificación y tema.
- `lib/services`: acceso a Supabase, autenticación, facturas, notificaciones y
  auditoría.
- `lib/models`: modelos de dominio.
- `lib/widgets`: componentes reutilizables.
- `supabase/migrations`: cambios versionados de la base de datos.
- `supabase/functions`: Edge Functions ejecutadas en Supabase.

La autenticación la administra Supabase Auth. La tabla `public.users` existente
se mantiene como perfil de la aplicación y se relaciona con `auth.users`; no se
crea una tabla alternativa de usuarios.

## Requisitos previos

- Flutter compatible con Dart `^3.9.2`.
- Node.js LTS y npm, solo si se utilizará Supabase CLI.
- Un proyecto de Supabase.
- Un proveedor de correo (opcional) como Resend para recordatorios por email.

## Instalación local

```powershell
flutter pub get
flutter run
```

Para verificar el proyecto:

```powershell
flutter analyze
```

## Configuración de Supabase

La configuración pública de Supabase está en
[`lib/config/supabase_config.dart`](lib/config/supabase_config.dart).
La clave utilizada por Flutter debe ser una clave publicable/anon y nunca una
clave secreta o `service_role`.

En Supabase deben configurarse:

1. Confirmación de correo electrónico en Authentication.
2. URLs permitidas para callback y recuperación de contraseña.
3. Row Level Security (RLS) para las tablas de datos.
4. Los secretos de Edge Functions, cuando se utilice correo:

   ```text
   RESEND_API_KEY
   MAIL_FROM
   ```

`SUPABASE_URL` y las credenciales internas de las Edge Functions son secretos
administrados por Supabase. No deben copiarse a Flutter ni al repositorio.

## Migraciones

La migración de preferencias de notificaciones se encuentra en
[`supabase/migrations/202609210001_email_notifications.sql`](supabase/migrations/202609210001_email_notifications.sql).
La tabla de auditoría se define en
[`supabase/migrations/202609230002_audit_logs.sql`](supabase/migrations/202609230002_audit_logs.sql).

La tabla `audit_logs`:

- relaciona cada evento con `auth.users`;
- permite insertar y consultar únicamente eventos propios mediante RLS;
- no permite modificar ni eliminar eventos desde la aplicación;
- no guarda contraseñas, tokens ni claves privadas.

Si la tabla ya fue creada manualmente en Supabase, la migración es idempotente y
puede utilizarse para mantener la configuración versionada.

La migración
[`supabase/migrations/202609300001_bill_notification_channels.sql`](supabase/migrations/202609300001_bill_notification_channels.sql)
guarda los canales y la hora UTC de recordatorio de cada factura, y programa la
Edge Function cada minuto mediante Supabase Cron.

Antes de aplicar esta migración, crea en **Supabase → Database → Vault** un
secreto llamado `billtracker_service_role_key` con el valor de la clave JWT
`service_role` del proyecto. La clave queda en Vault y no se guarda en el
repositorio ni en Flutter. La migración se detiene si el secreto no existe.

## Supabase CLI

Instalación local de la CLI:

```powershell
npm install --save-dev supabase
npx supabase login
npx supabase link --project-ref TU_PROJECT_REF
```

Aplicar migraciones remotas:

```powershell
npx supabase db push
```

Desplegar las funciones:

```powershell
npx supabase functions deploy send-bill-reminders --use-api
npx supabase functions deploy send-test-notification --use-api
npx supabase functions deploy delete-account --use-api
```

Docker no es necesario para vincular el proyecto ni para trabajar contra
Supabase remoto. Solo hace falta para levantar el stack local de Supabase.

## Edge Functions y correo

La función [`send-bill-reminders`](supabase/functions/send-bill-reminders/index.ts)
consulta facturas pendientes según los canales elegidos en cada factura,
registra cada entrega y envía correo e inbox a la hora programada.

Los valores `RESEND_API_KEY` y `MAIL_FROM` se crean en **Supabase → Edge
Functions → Secrets**. Nunca deben incluirse en archivos Dart, el README,
GitHub ni capturas de pantalla.

El cron invoca la función cada minuto. El usuario configura anticipación de 1 a
10 días y una hora local; la aplicación convierte el instante a UTC. El correo
se envía a la dirección asociada a la cuenta, que puede ser Gmail. En móvil, el
canal push es una notificación local del dispositivo; la web no implementa push
de navegador.

La función `send-test-notification` valida la sesión autenticada y envía un
correo de prueba a la dirección de la cuenta actual. La notificación interna se
guarda en `notifications`; en Android/iOS se muestra además una notificación
local inmediata. La versión web no implementa push del navegador.

## Seguridad

- Las contraseñas son gestionadas por Supabase Auth; la aplicación no las guarda
  ni aplica un hash manual.
- La comunicación de producción utiliza HTTPS.
- Las operaciones de datos deben estar protegidas con RLS usando `auth.uid()`.
- Las consultas de facturas verifican además el usuario autenticado.
- La auditoría registra acciones de autenticación, facturas, preferencias y
  eliminación de cuenta.
- Los logs de la aplicación no deben contener contraseñas, tokens, claves ni
  información financiera innecesaria.

## Alcance actual

Los backups administrados y la restauración de base de datos quedan fuera del
alcance de esta versión debido a las limitaciones del plan utilizado. No se
debe afirmar que existe backup automático si no está configurado en la
infraestructura.

## Solución de problemas

- `supabase status` requiere Docker o Podman porque inspecciona el entorno local;
  no es una prueba de disponibilidad del proyecto remoto.
- Si una función no encuentra `RESEND_API_KEY`, revisa los Secrets del proyecto
  y vuelve a desplegarla.
- Si una consulta devuelve un error de autorización, revisa que el usuario tenga
  una sesión válida y que la política RLS corresponda a la columna `user_id`.
