# Supabase Edge Functions

Deploy from this repository with the Supabase CLI:

```bash
supabase functions deploy delete-account
supabase functions deploy send-bill-reminders
supabase functions deploy send-test-notification
supabase secrets set RESEND_API_KEY=... MAIL_FROM="BillTracker <onboarding@resend.dev>"
```

The `202609300001_bill_notification_channels.sql` migration schedules
`send-bill-reminders` every minute with Supabase Cron. Before applying it, create
the `billtracker_service_role_key` secret in Supabase Vault. The secret is used
only by the scheduled database request and must never be committed.
Never put these secrets in Flutter, GitHub Pages, or the repository.

`send-test-notification` requires an authenticated Supabase session and sends a
single test email to the current user's account email. It uses the same
`RESEND_API_KEY` and `MAIL_FROM` secrets.
