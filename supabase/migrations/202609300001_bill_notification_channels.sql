alter table public.bills
  add column if not exists reminder_at timestamptz,
  add column if not exists reminder_push_enabled boolean not null default true,
  add column if not exists reminder_email_enabled boolean not null default true,
  add column if not exists reminder_in_app_enabled boolean not null default true;

update public.bills
set reminder_at =
  (
    due_date::date
    - make_interval(days => coalesce(reminder_days, 3))
    + make_interval(mins => coalesce(reminder_time_minutes, 540))
  ) at time zone 'UTC'
where reminder_at is null;

update public.bills b
set reminder_email_enabled =
  coalesce(p.email_enabled and p.due_date_reminders, true)
from public.notification_preferences p
where p.user_id = b.user_id;

create index if not exists bills_pending_reminder_at_idx
  on public.bills(reminder_at)
  where status = 'pending';

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
declare
  existing_job_id bigint;
begin
  if not exists (
    select 1
    from vault.decrypted_secrets
    where name = 'billtracker_service_role_key'
  ) then
    raise exception
      'Create the Vault secret billtracker_service_role_key before applying this migration.';
  end if;

  select jobid
    into existing_job_id
  from cron.job
  where jobname = 'bill-reminders-every-minute';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'bill-reminders-every-minute',
    '* * * * *',
    $job$
      select net.http_post(
        url := 'https://zvvvkkekxlokpajrpggv.supabase.co/functions/v1/send-bill-reminders',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (
            select decrypted_secret
            from vault.decrypted_secrets
            where name = 'billtracker_service_role_key'
          )
        ),
        body := '{}'::jsonb
      );
    $job$
  );
end;
$$;
