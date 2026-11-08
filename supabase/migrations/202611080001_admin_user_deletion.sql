create or replace function public.admin_delete_user_data(
  p_target_user_id uuid,
  p_admin_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_preferences integer;
  deleted_notifications integer;
  deleted_gamifications integer;
  deleted_bills integer;
  deleted_services integer;
  deleted_profiles integer;
begin
  if p_target_user_id is null or p_admin_user_id is null then
    raise exception using
      errcode = '22004',
      message = 'Target user and administrator IDs are required';
  end if;

  if p_target_user_id = p_admin_user_id then
    raise exception using
      errcode = '42501',
      message = 'You cannot delete your own account';
  end if;

  if not exists (
    select 1
    from public.admin_roles as role
    where role.user_id = p_admin_user_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Administrator access required';
  end if;

  if exists (
    select 1
    from public.admin_roles as role
    where role.user_id = p_target_user_id
  ) then
    raise exception using
      errcode = '42501',
      message = 'Administrator accounts cannot be deleted here';
  end if;

  if exists (
    select 1
    from public.services as service
    join public.bills as bill on bill.service_id = service.id
    where service.user_id = p_target_user_id
      and bill.user_id <> p_target_user_id
  ) then
    raise exception using
      errcode = '23503',
      message = 'Cannot delete this account because one of its services is referenced by another user bill';
  end if;

  delete from public.notification_preferences
  where user_id = p_target_user_id;
  get diagnostics deleted_preferences = row_count;

  delete from public.notifications
  where user_id = p_target_user_id;
  get diagnostics deleted_notifications = row_count;

  delete from public.gamifications
  where user_id = p_target_user_id;
  get diagnostics deleted_gamifications = row_count;

  delete from public.bills
  where user_id = p_target_user_id;
  get diagnostics deleted_bills = row_count;

  delete from public.services
  where user_id = p_target_user_id;
  get diagnostics deleted_services = row_count;

  delete from public.users
  where id = p_target_user_id;
  get diagnostics deleted_profiles = row_count;

  return jsonb_build_object(
    'preferences', deleted_preferences,
    'notifications', deleted_notifications,
    'gamifications', deleted_gamifications,
    'bills', deleted_bills,
    'services', deleted_services,
    'profiles', deleted_profiles
  );
end;
$$;

revoke all on function public.admin_delete_user_data(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.admin_delete_user_data(uuid, uuid)
  to service_role;
