CREATE OR REPLACE FUNCTION public.refresh_gamification_after_bill_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (
      SELECT 1 FROM auth.users WHERE id = OLD.user_id
    ) THEN
      IF OLD.status = 'paid' THEN
        INSERT INTO public.paid_bill_history (
          bill_id,
          user_id,
          due_date,
          paid_at
        )
        VALUES (
          OLD.id,
          OLD.user_id,
          public.billtracker_local_civil_date(
            to_jsonb(OLD)->>'due_date'
          ),
          public.billtracker_paid_at(to_jsonb(OLD)->>'paid_date')
        )
        ON CONFLICT (bill_id) DO UPDATE
        SET
          user_id = EXCLUDED.user_id,
          due_date = EXCLUDED.due_date,
          paid_at = EXCLUDED.paid_at,
          archived_at = now();
      END IF;

      PERFORM public.reconcile_gamification_for_user(OLD.user_id);
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.status = 'paid' THEN
    UPDATE public.paid_bill_history
    SET
      user_id = NEW.user_id,
      due_date = public.billtracker_local_civil_date(
        to_jsonb(NEW)->>'due_date'
      ),
      paid_at = public.billtracker_paid_at(to_jsonb(NEW)->>'paid_date')
    WHERE bill_id = NEW.id;
  ELSIF OLD.status = 'paid' THEN
    DELETE FROM public.paid_bill_history
    WHERE bill_id = OLD.id;
  END IF;

  PERFORM public.reconcile_gamification_for_user(NEW.user_id);
  IF TG_OP = 'UPDATE' AND OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    PERFORM public.reconcile_gamification_for_user(OLD.user_id);
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_gamification_after_bill_change()
  FROM PUBLIC, anon, authenticated;
