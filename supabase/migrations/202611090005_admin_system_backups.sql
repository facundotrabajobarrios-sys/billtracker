create table if not exists public.admin_system_backups (
  id uuid primary key default gen_random_uuid(),
  requested_by uuid not null references auth.users(id) on delete cascade,
  status text not null check (
    status in ('queued', 'running', 'completed', 'failed')
  ),
  object_path text,
  error_message text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint admin_system_backups_completed_object_check
    check (status <> 'completed' or object_path is not null)
);

create index if not exists admin_system_backups_requester_created_idx
  on public.admin_system_backups(requested_by, created_at desc);

alter table public.admin_system_backups enable row level security;
revoke all on public.admin_system_backups from public, anon, authenticated;
grant all on public.admin_system_backups to service_role;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'system-backups',
  'system-backups',
  false,
  2147483648,
  array['application/zip']::text[]
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;
