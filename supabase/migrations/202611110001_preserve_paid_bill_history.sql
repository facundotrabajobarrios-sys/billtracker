CREATE OR REPLACE FUNCTION public.billtracker_paid_at(p_value text)
RETURNS timestamptz
LANGUAGE plpgsql
IMMUTABLE
SET search_path = pg_catalog
AS $$
BEGIN
  IF p_value IS NULL THEN
    RETURN NULL;
  END IF;

  IF p_value ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RETURN p_value::date::timestamp AT TIME ZONE 'America/Asuncion';
  END IF;

  IF p_value ~ '([zZ]|[+-][0-9]{2}(:?[0-9]{2})?)$' THEN
    RETURN p_value::timestamptz;
  END IF;

  RETURN p_value::timestamp AT TIME ZONE 'America/Asuncion';
END;
$$;

CREATE OR REPLACE FUNCTION public.billtracker_local_civil_date(p_value text)
RETURNS date
LANGUAGE sql
IMMUTABLE
SET search_path = pg_catalog, public
AS $$
  SELECT CASE
    WHEN p_value IS NULL THEN NULL
    WHEN p_value ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      THEN p_value::date
    ELSE (
      public.billtracker_paid_at(p_value)
      AT TIME ZONE 'America/Asuncion'
    )::date
  END;
$$;

CREATE TABLE IF NOT EXISTS public.paid_bill_history (
  bill_id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  due_date date,
  paid_at timestamptz,
  archived_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS paid_bill_history_user_paid_at_idx
  ON public.paid_bill_history(user_id, paid_at, bill_id);

ALTER TABLE public.paid_bill_history ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.paid_bill_history FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.paid_bill_history TO authenticated;
GRANT ALL ON public.paid_bill_history TO service_role;

DROP POLICY IF EXISTS "Users can read their own paid bill history"
  ON public.paid_bill_history;
CREATE POLICY "Users can read their own paid bill history"
  ON public.paid_bill_history
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

ALTER TABLE public.gamifications
  ADD COLUMN IF NOT EXISTS days_without_overdue integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS has_overdue_bills boolean NOT NULL DEFAULT false;

INSERT INTO public.paid_bill_history (bill_id, user_id, due_date, paid_at)
SELECT
  bill.id,
  bill.user_id,
  public.billtracker_local_civil_date(
    to_jsonb(bill)->>'due_date'
  ),
  public.billtracker_paid_at(bill.paid_date::text)
FROM public.bills AS bill
WHERE bill.status = 'paid'
ON CONFLICT (bill_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.reconcile_gamification_for_user(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_badges text[] := ARRAY[]::text[];
  v_earned_badges text[] := ARRAY[]::text[];
  v_keep_id uuid;
  v_total_paid integer := 0;
  v_on_time integer := 0;
  v_streak integer := 0;
  v_points integer := 0;
  v_level integer := 1;
  v_last_payment_date date;
  v_latest_late_payment date;
  v_registered_date date;
  v_today date := timezone('America/Asuncion', now())::date;
  v_has_active_overdue boolean := false;
  v_days_without_overdue integer := 0;
  v_badge text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  PERFORM pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_user_id::text, 0)
  );

  SELECT COALESCE(
    array_agg(DISTINCT badge),
    ARRAY[]::text[]
  )
  INTO v_badges
  FROM public.gamifications AS g
  CROSS JOIN LATERAL unnest(
    COALESCE(g.unlocked_badges, ARRAY[]::text[])
  ) AS badges(badge)
  WHERE g.user_id = p_user_id;

  WITH paid AS (
    SELECT
      bill.id,
      public.billtracker_paid_at(bill.paid_date::text) AS paid_at,
      public.billtracker_local_civil_date(
        to_jsonb(bill)->>'due_date'
      ) AS due_day
    FROM public.bills AS bill
    WHERE bill.user_id = p_user_id
      AND bill.status = 'paid'
      AND NOT EXISTS (
        SELECT 1
        FROM public.paid_bill_history AS history
        WHERE history.bill_id = bill.id
      )

    UNION ALL

    SELECT
      history.bill_id AS id,
      history.paid_at,
      history.due_date AS due_day
    FROM public.paid_bill_history AS history
    WHERE history.user_id = p_user_id
  ),
  marked AS (
    SELECT
      paid.*,
      public.billtracker_local_civil_date(paid_at::text) AS paid_day,
      COALESCE(
        paid_at IS NOT NULL
        AND due_day IS NOT NULL
        AND public.billtracker_local_civil_date(paid_at::text) <= due_day,
        false
      ) AS on_time
    FROM paid
  ),
  ordered AS (
    SELECT
      *,
      row_number() OVER (ORDER BY paid_at NULLS FIRST, id) AS sequence,
      lag(paid_at) OVER (ORDER BY paid_at NULLS FIRST, id) AS previous_paid_at,
      lag(on_time) OVER (ORDER BY paid_at NULLS FIRST, id) AS previous_on_time
    FROM marked
  ),
  totals AS (
    SELECT
      count(*)::integer AS total_paid,
      count(*) FILTER (WHERE on_time)::integer AS on_time_count,
      count(*) FILTER (
        WHERE on_time
          AND sequence > COALESCE(
            (SELECT max(sequence) FROM ordered WHERE NOT on_time),
            0
          )
      )::integer AS current_streak,
      COALESCE(
        sum(
          CASE
            WHEN on_time
              AND previous_on_time
              AND paid_at - previous_paid_at <= interval '1 day'
            THEN 5
            ELSE 0
          END
        ),
        0
      )::integer AS consecutive_bonus,
      max(paid_day) AS last_payment,
      max(paid_day) FILTER (
        WHERE paid_at IS NOT NULL
          AND due_day IS NOT NULL
          AND paid_day > due_day
      ) AS latest_late_payment
    FROM ordered
  )
  SELECT
    total_paid,
    on_time_count,
    current_streak,
    total_paid * 10 + on_time_count * 5 + consecutive_bonus,
    last_payment,
    latest_late_payment
  INTO
    v_total_paid,
    v_on_time,
    v_streak,
    v_points,
    v_last_payment_date,
    v_latest_late_payment
  FROM totals;

  SELECT public.billtracker_local_civil_date(created_at::text)
  INTO v_registered_date
  FROM public.users
  WHERE id = p_user_id;

  SELECT EXISTS (
    SELECT 1
    FROM public.bills
    WHERE user_id = p_user_id
      AND status <> 'paid'
      AND (
        status = 'overdue'
        OR public.billtracker_local_civil_date(
          to_jsonb(bills)->>'due_date'
        ) < v_today
      )
  )
  INTO v_has_active_overdue;

  IF NOT v_has_active_overdue AND v_registered_date IS NOT NULL
  THEN
    v_days_without_overdue := greatest(
      v_today - greatest(
        v_registered_date,
        COALESCE(v_latest_late_payment, v_registered_date)
      ),
      0
    );
  END IF;

  v_level := CASE
    WHEN v_points < 100 THEN 1
    WHEN v_points < 300 THEN 2
    WHEN v_points < 600 THEN 3
    WHEN v_points < 1000 THEN 4
    WHEN v_points < 1500 THEN 5
    WHEN v_points < 2100 THEN 6
    WHEN v_points < 2800 THEN 7
    ELSE 8
  END;

  IF v_total_paid >= 1 THEN
    v_earned_badges := array_append(v_earned_badges, 'first_payment');
  END IF;
  IF v_streak >= 3 THEN
    v_earned_badges := array_append(v_earned_badges, 'on_time_3');
  END IF;
  IF v_streak >= 7 THEN
    v_earned_badges := array_append(v_earned_badges, 'on_time_7');
  END IF;
  IF v_streak >= 30 THEN
    v_earned_badges := array_append(v_earned_badges, 'on_time_30');
  END IF;
  IF v_total_paid >= 10 THEN
    v_earned_badges := array_append(v_earned_badges, 'paid_10');
  END IF;
  IF v_total_paid >= 50 THEN
    v_earned_badges := array_append(v_earned_badges, 'paid_50');
  END IF;
  IF v_days_without_overdue >= 30 THEN
    v_earned_badges := array_append(v_earned_badges, 'no_overdue_30');
  END IF;

  FOREACH v_badge IN ARRAY v_earned_badges LOOP
    IF NOT (v_badge = ANY(v_badges)) THEN
      v_badges := array_append(v_badges, v_badge);
    END IF;
  END LOOP;

  SELECT id
  INTO v_keep_id
  FROM public.gamifications
  WHERE user_id = p_user_id
  ORDER BY id
  LIMIT 1;

  IF v_keep_id IS NULL THEN
    INSERT INTO public.gamifications (
      user_id,
      total_points,
      current_level,
      streak_days,
      total_paid_bills,
      on_time_payments,
      unlocked_badges,
      last_payment_date,
      days_without_overdue,
      has_overdue_bills,
      updated_at
    )
    VALUES (
      p_user_id,
      v_points,
      v_level,
      v_streak,
      v_total_paid,
      v_on_time,
      v_badges,
      v_last_payment_date,
      v_days_without_overdue,
      v_has_active_overdue,
      now()
    );
  ELSE
    DELETE FROM public.gamifications
    WHERE user_id = p_user_id
      AND id <> v_keep_id;

    UPDATE public.gamifications
    SET
      total_points = v_points,
      current_level = v_level,
      streak_days = v_streak,
      total_paid_bills = v_total_paid,
      on_time_payments = v_on_time,
      unlocked_badges = v_badges,
      last_payment_date = v_last_payment_date,
      days_without_overdue = v_days_without_overdue,
      has_overdue_bills = v_has_active_overdue,
      updated_at = now()
    WHERE id = v_keep_id;
  END IF;

  UPDATE public.users
  SET
    points = v_points,
    level = v_level
  WHERE id = p_user_id
    AND (
      points IS DISTINCT FROM v_points
      OR level IS DISTINCT FROM v_level
    );
END;
$$;

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
        ON CONFLICT (bill_id) DO NOTHING;
      END IF;

      PERFORM public.reconcile_gamification_for_user(OLD.user_id);
    END IF;
    RETURN OLD;
  END IF;

  PERFORM public.reconcile_gamification_for_user(NEW.user_id);
  IF TG_OP = 'UPDATE' AND OLD.user_id IS DISTINCT FROM NEW.user_id THEN
    PERFORM public.reconcile_gamification_for_user(OLD.user_id);
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.billtracker_paid_at(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.billtracker_local_civil_date(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.reconcile_gamification_for_user(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_gamification_after_bill_change()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN
    SELECT user_id FROM public.gamifications
    UNION
    SELECT user_id FROM public.bills WHERE status = 'paid'
    UNION
    SELECT user_id FROM public.paid_bill_history
    UNION
    SELECT id FROM public.users WHERE points <> 0 OR level <> 0
  LOOP
    PERFORM public.reconcile_gamification_for_user(v_user_id);
  END LOOP;
END;
$$;
