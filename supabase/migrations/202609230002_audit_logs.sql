create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  action text not null check (
    action in (
      'login',
      'logout',
      'register',
      'password_reset_requested',
      'password_changed',
      'bill_created',
      'bill_updated',
      'bill_deleted',
      'bill_marked_paid',
      'notification_preferences_updated',
      'account_deleted'
    )
  ),
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  ip_address inet,
  user_agent text,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_user_id_created_at_idx
  on public.audit_logs(user_id, created_at desc);

create index if not exists audit_logs_action_created_at_idx
  on public.audit_logs(action, created_at desc);

create index if not exists audit_logs_entity_idx
  on public.audit_logs(entity_type, entity_id);

alter table public.audit_logs enable row level security;

drop policy if exists "Users can insert their own audit logs"
  on public.audit_logs;

create policy "Users can insert their own audit logs"
  on public.audit_logs
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can read their own audit logs"
  on public.audit_logs;

create policy "Users can read their own audit logs"
  on public.audit_logs
  for select
  to authenticated
  using (auth.uid() = user_id);
