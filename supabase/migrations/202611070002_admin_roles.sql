create table if not exists public.admin_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  must_change_password boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.admin_roles enable row level security;
revoke all on public.admin_roles from anon, authenticated;

create table if not exists public.admin_bootstrap_state (
  id smallint primary key default 1 check (id = 1),
  status text not null check (status in ('pending', 'completed')),
  admin_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.admin_bootstrap_state enable row level security;
revoke all on public.admin_bootstrap_state from anon, authenticated;

create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  action text not null,
  target_user_id uuid,
  target_bill_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created_at_idx
  on public.admin_audit_logs(created_at desc);
create index if not exists admin_audit_logs_admin_user_id_idx
  on public.admin_audit_logs(admin_user_id, created_at desc);

alter table public.admin_audit_logs enable row level security;
revoke all on public.admin_audit_logs from anon, authenticated;

create table if not exists public.admin_settings (
  key text primary key check (key = 'public_announcement'),
  value text not null default '',
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

insert into public.admin_settings (key, value)
values ('public_announcement', '')
on conflict (key) do nothing;

alter table public.admin_settings enable row level security;
revoke all on public.admin_settings from anon, authenticated;

create or replace function public.get_admin_status()
returns table (is_admin boolean, must_change_password boolean)
language sql
stable
security definer
set search_path = pg_catalog
as $$
  select
    exists (
      select 1
      from public.admin_roles as role
      where role.user_id = auth.uid()
    ),
    coalesce(
      (
        select role.must_change_password
        from public.admin_roles as role
        where role.user_id = auth.uid()
      ),
      false
    );
$$;

revoke all on function public.get_admin_status() from public, anon;
grant execute on function public.get_admin_status() to authenticated;

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
  limit 1;
$$;

revoke all on function public.get_public_app_notice() from public;
grant execute on function public.get_public_app_notice() to anon, authenticated;
