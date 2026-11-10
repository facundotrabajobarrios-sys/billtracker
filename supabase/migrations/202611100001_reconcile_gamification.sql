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
  v_has_active_overdue boolean := false;
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
      id,
      paid_date,
      due_date,
      COALESCE(
        paid_date IS NOT NULL
        AND due_date IS NOT NULL
        AND paid_date <= due_date,
        false
      ) AS on_time
    FROM public.bills
    WHERE user_id = p_user_id
      AND status = 'paid'
  ),
  ordered AS (
    SELECT
      *,
      row_number() OVER (ORDER BY paid_date NULLS FIRST, id) AS sequence,
      lag(paid_date) OVER (ORDER BY paid_date NULLS FIRST, id) AS previous_paid_date,
      lag(on_time) OVER (ORDER BY paid_date NULLS FIRST, id) AS previous_on_time
    FROM paid
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
              AND paid_date - previous_paid_date <= 1
            THEN 5
            ELSE 0
          END
        ),
        0
      )::integer AS consecutive_bonus,
      max(paid_date) AS last_payment,
      max(paid_date) FILTER (WHERE paid_date > due_date) AS latest_late_payment
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

  SELECT created_at::date
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
        OR due_date < CURRENT_DATE
      )
  )
  INTO v_has_active_overdue;

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

  IF NOT v_has_active_overdue
    AND CURRENT_DATE - GREATEST(v_registered_date, v_latest_late_payment) >= 30
  THEN
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
    IF OLD.status = 'paid' THEN
      PERFORM public.reconcile_gamification_for_user(OLD.user_id);
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.status = 'paid' THEN
    PERFORM public.reconcile_gamification_for_user(NEW.user_id);
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'paid' THEN
    PERFORM public.reconcile_gamification_for_user(OLD.user_id);
  END IF;

  RETURN NEW;
END;
$$;

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
    SELECT id FROM public.users WHERE points <> 0 OR level <> 0
  LOOP
    PERFORM public.reconcile_gamification_for_user(v_user_id);
  END LOOP;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS gamifications_user_id_key
  ON public.gamifications (user_id);

DROP TRIGGER IF EXISTS bills_reconcile_gamification ON public.bills;
CREATE TRIGGER bills_reconcile_gamification
  AFTER INSERT OR DELETE OR UPDATE OF status, paid_date, due_date
  ON public.bills
  FOR EACH ROW
  EXECUTE FUNCTION public.refresh_gamification_after_bill_change();
