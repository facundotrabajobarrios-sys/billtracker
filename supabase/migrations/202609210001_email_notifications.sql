-- Email reminders and notification preferences.
alter table public.bills
  add column if not exists reminder_time_minutes integer not null default 540
  check (reminder_time_minutes between 0 and 1439);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email_enabled boolean not null default true,
  due_date_reminders boolean not null default true,
  payment_confirmations boolean not null default true,
  weekly_summary boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.bill_reminder_deliveries (
  bill_id uuid not null references public.bills(id) on delete cascade,
  reminder_at timestamptz not null,
  email_sent_at timestamptz,
  notification_created_at timestamptz,
  primary key (bill_id, reminder_at)
);

alter table public.bill_reminder_deliveries enable row level security;

alter table public.notification_preferences enable row level security;

drop policy if exists "Users can read their notification preferences"
  on public.notification_preferences;

create policy "Users can read their notification preferences"
  on public.notification_preferences for select
  using (auth.uid() = user_id);

drop policy if exists "Users can insert their notification preferences"
  on public.notification_preferences;

create policy "Users can insert their notification preferences"
  on public.notification_preferences for insert
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their notification preferences"
  on public.notification_preferences;

create policy "Users can update their notification preferences"
  on public.notification_preferences for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
