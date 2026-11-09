create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.expire_public_system_notice()
returns void
language sql
security definer
set search_path = ''
as $$
  update public.admin_settings
  set value = ''
  where key = 'public_announcement'
    and value <> ''
    and updated_at <= now() - interval '24 hours';
$$;

revoke all on function public.expire_public_system_notice()
  from public, anon, authenticated;
grant execute on function public.expire_public_system_notice()
  to service_role;

do $$
declare
  existing_job_id bigint;
begin
  select jobid into existing_job_id
  from cron.job
  where jobname = 'expire-public-system-notice';

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'expire-public-system-notice',
    '* * * * *',
    'select public.expire_public_system_notice();'
  );
end;
$$;
