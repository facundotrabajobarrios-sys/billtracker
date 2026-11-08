alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    'reminder'::text,
    'warning'::text,
    'success'::text,
    'info'::text,
    'announcement'::text
  ]));

create or replace function public.notify_gamification_level_up()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.current_level > old.current_level then
    insert into public.notifications (
      user_id,
      title,
      message,
      type,
      is_read
    )
    values (
      new.user_id,
      '¡Subiste de nivel!',
      format('Has alcanzado el nivel %s. ¡Sigue así!', new.current_level),
      'success',
      false
    );
  end if;

  return new;
end;
$$;

revoke all on function public.notify_gamification_level_up()
  from public, anon, authenticated;

drop trigger if exists gamification_level_up_notification
  on public.gamifications;

create trigger gamification_level_up_notification
  after update of current_level on public.gamifications
  for each row
  when (new.current_level > old.current_level)
  execute function public.notify_gamification_level_up();
