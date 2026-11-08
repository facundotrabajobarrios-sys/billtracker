alter table public.services
  add column if not exists is_active boolean not null default true,
  add column if not exists price numeric,
  add column if not exists category_id uuid references public.categories(id) on delete set null;

alter table public.services alter column user_id drop not null;

alter table public.categories
  add column if not exists description text,
  add column if not exists is_active boolean not null default true;

do $$
declare
  policy_row record;
begin
  for policy_row in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('services', 'categories')
  loop
    execute format(
      'drop policy %I on %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );
  end loop;
end;
$$;

alter table public.services enable row level security;
alter table public.categories enable row level security;

create policy "Users can read active catalog services"
  on public.services for select to authenticated
  using (
    (is_active and (user_id is null or user_id = auth.uid()))
    or exists (
      select 1
      from public.bills as bill
      where bill.service_id = services.id
        and bill.user_id = auth.uid()
    )
  );

create policy "Users can create their own services"
  on public.services for insert to authenticated
  with check (user_id = auth.uid());

create policy "Users can update their own services"
  on public.services for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "Users can delete their own services"
  on public.services for delete to authenticated
  using (user_id = auth.uid());

create policy "Users can read active categories"
  on public.categories for select to authenticated
  using (
    is_active
    or exists (
      select 1
      from public.bills as bill
      where bill.category_id = categories.id
        and bill.user_id = auth.uid()
    )
  );

grant select, insert, update, delete on public.services to authenticated;
grant select on public.categories to authenticated;
grant all on public.services, public.categories to service_role;

alter table public.notifications
  add column if not exists announcement_id uuid,
  add column if not exists sent_at timestamptz;

create table if not exists public.admin_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check (length(btrim(title)) between 1 and 120),
  message text not null check (length(btrim(message)) between 1 and 5000),
  created_by uuid not null references auth.users(id) on delete restrict,
  recipient_count integer not null default 0,
  published_at timestamptz not null default now()
);

alter table public.notifications
  drop constraint if exists notifications_announcement_id_fkey;
alter table public.notifications
  add constraint notifications_announcement_id_fkey
  foreign key (announcement_id) references public.admin_announcements(id)
  on delete set null;

create unique index if not exists notifications_announcement_user_unique
  on public.notifications(announcement_id, user_id)
  where announcement_id is not null;

create index if not exists notifications_active_announcements_idx
  on public.notifications(user_id, created_at desc)
  where announcement_id is not null;

create table if not exists public.announcement_email_deliveries (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.admin_announcements(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'sending', 'sent', 'failed')),
  attempts integer not null default 0,
  last_attempt_at timestamptz,
  sent_at timestamptz,
  provider_id text,
  error text,
  created_at timestamptz not null default now(),
  unique (announcement_id, user_id)
);

create index if not exists announcement_email_queue_idx
  on public.announcement_email_deliveries(status, last_attempt_at, created_at);

alter table public.admin_announcements enable row level security;
alter table public.announcement_email_deliveries enable row level security;
revoke all on public.admin_announcements from anon, authenticated;
revoke all on public.announcement_email_deliveries from anon, authenticated;
grant all on public.admin_announcements to service_role;
grant all on public.announcement_email_deliveries to service_role;
grant all on public.notifications to service_role;

create or replace function public.admin_publish_announcement(
  p_admin_user_id uuid,
  p_title text,
  p_message text,
  p_recipient_user_ids uuid[]
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_announcement_id uuid;
  recipient_count integer;
begin
  if not exists (
    select 1 from public.admin_roles
    where user_id = p_admin_user_id
  ) then
    raise exception using errcode = '42501', message = 'Administrator access required';
  end if;

  if length(btrim(coalesce(p_title, ''))) not between 1 and 120
    or length(btrim(coalesce(p_message, ''))) not between 1 and 5000 then
    raise exception using errcode = '22023', message = 'Invalid announcement title or message';
  end if;

  select count(distinct recipient_id)::integer
    into recipient_count
  from unnest(coalesce(p_recipient_user_ids, array[]::uuid[]))
    as recipients_input(recipient_id)
  join public.users as profile on profile.id = recipients_input.recipient_id;

  if recipient_count = 0 then
    raise exception using errcode = '22023', message = 'Announcement has no valid recipients';
  end if;

  insert into public.admin_announcements (title, message, created_by, recipient_count)
  values (btrim(p_title), btrim(p_message), p_admin_user_id, recipient_count)
  returning id into v_announcement_id;

  with recipients as (
    select distinct profile.id
    from unnest(coalesce(p_recipient_user_ids, array[]::uuid[]))
      as recipients_input(recipient_id)
    join public.users as profile on profile.id = recipients_input.recipient_id
  ),
  delivered as (
    insert into public.notifications (
      user_id, title, message, type, is_read, announcement_id, sent_at
    )
    select
      recipients.id, btrim(p_title), btrim(p_message), 'announcement',
      false, v_announcement_id, now()
    from recipients
    on conflict (announcement_id, user_id)
      where announcement_id is not null do nothing
    returning user_id
  )
  insert into public.announcement_email_deliveries (announcement_id, user_id)
  select v_announcement_id, delivered.user_id
  from delivered
  on conflict (announcement_id, user_id) do nothing;

  return jsonb_build_object(
    'announcementId', v_announcement_id,
    'recipientCount', recipient_count,
    'publishedAt', now()
  );
end;
$$;

revoke all on function public.admin_publish_announcement(uuid, text, text, uuid[])
  from public, anon, authenticated;
grant execute on function public.admin_publish_announcement(uuid, text, text, uuid[])
  to service_role;

create or replace function public.get_active_announcements()
returns table (
  id uuid,
  announcement_id uuid,
  title text,
  message text,
  is_read boolean,
  published_at timestamptz
)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select
    notification.id,
    announcement.id,
    notification.title,
    notification.message,
    notification.is_read,
    announcement.published_at
  from public.notifications as notification
  join public.admin_announcements as announcement
    on announcement.id = notification.announcement_id
  where notification.user_id = auth.uid()
    and auth.uid() is not null
    and announcement.published_at >= now() - interval '24 hours'
  order by announcement.published_at desc;
$$;

revoke all on function public.get_active_announcements() from public, anon;
grant execute on function public.get_active_announcements() to authenticated;

create or replace function public.claim_announcement_email_deliveries()
returns table (
  id uuid,
  announcement_id uuid,
  user_id uuid,
  title text,
  message text,
  attempts integer
)
language sql
security definer
set search_path = pg_catalog, public
as $$
  with claimable as (
    select delivery.id
    from public.announcement_email_deliveries as delivery
    where delivery.attempts < 5
      and (
        (delivery.status in ('pending', 'failed')
          and (
            delivery.last_attempt_at is null
            or delivery.last_attempt_at < now()
              - make_interval(mins => least(delivery.attempts * 5, 60))
          ))
        or (delivery.status = 'sending'
          and delivery.last_attempt_at < now() - interval '15 minutes')
      )
    order by delivery.created_at
    for update skip locked
    limit 25
  ),
  claimed as (
    update public.announcement_email_deliveries as delivery
    set status = 'sending',
        attempts = delivery.attempts + 1,
        last_attempt_at = now(),
        error = null
    from claimable
    where delivery.id = claimable.id
    returning delivery.id, delivery.announcement_id, delivery.user_id, delivery.attempts
  )
  select
    claimed.id,
    claimed.announcement_id,
    claimed.user_id,
    announcement.title,
    announcement.message,
    claimed.attempts
  from claimed
  join public.admin_announcements as announcement
    on announcement.id = claimed.announcement_id;
$$;

revoke all on function public.claim_announcement_email_deliveries()
  from public, anon, authenticated;
grant execute on function public.claim_announcement_email_deliveries()
  to service_role;

create or replace function public.admin_announcement_email_stats(
  p_announcement_ids uuid[]
)
returns table (
  announcement_id uuid,
  status text,
  delivery_count bigint
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    delivery.announcement_id,
    delivery.status,
    count(*)
  from public.announcement_email_deliveries as delivery
  where delivery.announcement_id = any(
    coalesce(p_announcement_ids, array[]::uuid[])
  )
  group by delivery.announcement_id, delivery.status;
$$;

revoke all on function public.admin_announcement_email_stats(uuid[])
  from public, anon, authenticated;
grant execute on function public.admin_announcement_email_stats(uuid[])
  to service_role;

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create extension if not exists supabase_vault with schema vault;

do $$
declare
  existing_job_id bigint;
begin
  if not exists (
    select 1 from vault.decrypted_secrets
    where name = 'billtracker_service_role_key'
  ) then
    raise exception
      'Create the Vault secret billtracker_service_role_key before applying this migration.';
  end if;

  select jobid into existing_job_id
  from cron.job
  where jobname = 'announcement-emails-every-minute';
  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'announcement-emails-every-minute',
    '* * * * *',
    $job$
      select net.http_post(
        url := 'https://zvvvkkekxlokpajrpggv.supabase.co/functions/v1/send-announcement-emails',
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
