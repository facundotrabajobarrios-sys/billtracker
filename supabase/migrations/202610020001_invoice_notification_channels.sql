alter table public.bills
  add column if not exists reminder_at timestamptz,
  add column if not exists reminder_push_enabled boolean not null default true,
  add column if not exists reminder_email_enabled boolean not null default true,
  add column if not exists reminder_in_app_enabled boolean not null default true;

update public.bills as bill
set reminder_email_enabled =
    coalesce(preferences.email_enabled and preferences.due_date_reminders, true),
  reminder_at =
    (
      (bill.due_date - coalesce(bill.reminder_days, 3))::timestamp
      + make_interval(mins => coalesce(bill.reminder_time_minutes, 540))
    ) at time zone 'America/Asuncion'
from public.notification_preferences as preferences
where preferences.user_id = bill.user_id
  and bill.reminder_at is null;

update public.bills
set reminder_at =
  (
    (due_date - coalesce(reminder_days, 3))::timestamp
    + make_interval(mins => coalesce(reminder_time_minutes, 540))
  ) at time zone 'America/Asuncion'
where reminder_at is null;

create index if not exists bills_pending_reminder_at_idx
  on public.bills (reminder_at)
  where status = 'pending'
    and (reminder_email_enabled or reminder_in_app_enabled);

create table if not exists public.bill_reminder_deliveries (
  bill_id uuid not null references public.bills(id) on delete cascade,
  reminder_at timestamptz not null,
  email_sent_at timestamptz,
  notification_created_at timestamptz,
  primary key (bill_id, reminder_at)
);

alter table public.bill_reminder_deliveries
  add column if not exists email_sent_at timestamptz,
  add column if not exists notification_created_at timestamptz;
