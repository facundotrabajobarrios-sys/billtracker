alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'reminder'::text,
    'warning'::text,
    'success'::text,
    'info'::text,
    'announcement'::text,
    'system'::text
  ]));

create or replace function public.admin_update_system_notice(
  p_admin_user_id uuid,
  p_message text
)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_message text := btrim(coalesce(p_message, ''));
  v_updated_at timestamptz;
begin
  if not exists (
    select 1
    from public.admin_roles as role
    where role.user_id = p_admin_user_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Administrator access required';
  end if;

  if length(v_message) > 500 then
    raise exception using
      errcode = '22023',
      message = 'System notice must be 500 characters or fewer';
  end if;

  insert into public.admin_settings (
    key,
    value,
    updated_by,
    updated_at
  )
  values (
    'public_announcement',
    v_message,
    p_admin_user_id,
    now()
  )
  on conflict (key) do update
  set value = excluded.value,
      updated_by = excluded.updated_by,
      updated_at = excluded.updated_at
  returning updated_at into v_updated_at;

  if v_message <> '' then
    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      is_read
    )
    select
      profile.id,
      'Aviso del sistema',
      v_message,
      'system',
      false
    from public.users as profile;
  end if;

  return v_updated_at;
end;
$$;

revoke all on function public.admin_update_system_notice(uuid, text)
  from public, anon, authenticated;
grant execute on function public.admin_update_system_notice(uuid, text)
  to service_role;

create or replace function public.get_public_app_notice()
returns text
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select setting.value
  from public.admin_settings as setting
  where setting.key = 'public_announcement'
    and setting.value <> ''
    and setting.updated_at >= now() - interval '24 hours'
  limit 1;
$$;

revoke all on function public.get_public_app_notice() from public;
grant execute on function public.get_public_app_notice() to anon, authenticated;

create or replace function public.get_active_system_notice()
returns table (
  message text,
  expires_in_seconds integer
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    setting.value,
    greatest(
      0,
      floor(extract(epoch from (
        setting.updated_at + interval '24 hours' - now()
      )))::integer
    )
  from public.admin_settings as setting
  where setting.key = 'public_announcement'
    and setting.value <> ''
    and setting.updated_at >= now() - interval '24 hours'
  limit 1;
$$;

revoke all on function public.get_active_system_notice()
  from public, anon;
grant execute on function public.get_active_system_notice()
  to authenticated;
