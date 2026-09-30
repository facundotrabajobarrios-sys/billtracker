# Supabase Edge Functions

Deploy from this repository with the Supabase CLI:

```bash
supabase functions deploy delete-account
supabase functions deploy send-bill-reminders
supabase functions deploy send-test-notification
supabase secrets set RESEND_API_KEY=... MAIL_FROM="BillTracker <onboarding@resend.dev>"
```

Configure Supabase Cron to invoke `send-bill-reminders` every 15 or 30 minutes.
Never put these secrets in Flutter, GitHub Pages, or the repository.

`send-test-notification` requires an authenticated Supabase session and sends a
single test email to the current user's account email. It uses the same
`RESEND_API_KEY` and `MAIL_FROM` secrets.
