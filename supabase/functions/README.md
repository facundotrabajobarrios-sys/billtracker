# Supabase Edge Functions

Deploy from this repository with the Supabase CLI:

```bash
supabase functions deploy delete-account
supabase functions deploy send-bill-reminders
supabase secrets set RESEND_API_KEY=... MAIL_FROM="BillTracker <onboarding@resend.dev>"
```

Configure Supabase Cron to invoke `send-bill-reminders` every 15 or 30 minutes.
Never put these secrets in Flutter, GitHub Pages, or the repository.
