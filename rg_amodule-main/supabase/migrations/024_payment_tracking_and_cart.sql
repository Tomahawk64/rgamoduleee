-- Migration: Payment Tracking and Cart System
-- Description: Adds comprehensive payment status tracking, cart persistence, and payment reminders
-- Created: 2026-04-21

-- =============================================================================
-- 1. PAYMENT STATUS ENHANCEMENT FOR ORDERS
-- =============================================================================

-- Add payment_status and payment_metadata columns to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'pending' 
CHECK (payment_status IN ('pending', 'initiated', 'completed', 'failed', 'cancelled', 'refunded'));

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_method text DEFAULT 'razorpay';

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS razorpay_order_id text;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS razorpay_payment_id text;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS razorpay_signature text;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_metadata jsonb;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_error_message text;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_attempted_at timestamptz;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS payment_completed_at timestamptz;

-- Create index for faster payment status queries
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_razorpay_payment_id ON public.orders(razorpay_payment_id);

-- =============================================================================
-- 2. PAYMENT STATUS ENHANCEMENT FOR BOOKINGS
-- =============================================================================

-- Add payment_status columns to bookings table (for future booking-based purchases)
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'pending'
CHECK (payment_status IN ('pending', 'initiated', 'completed', 'failed', 'cancelled', 'refunded'));

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS razorpay_order_id text;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS razorpay_payment_id text;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS razorpay_signature text;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_metadata jsonb;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_error_message text;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_attempted_at timestamptz;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS payment_completed_at timestamptz;

-- Create index for faster payment status queries
CREATE INDEX IF NOT EXISTS idx_bookings_payment_status ON public.bookings(payment_status);

-- =============================================================================
-- 3. PAYMENT LOGS TABLE (for audit trail and debugging)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.payment_logs (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                   uuid NOT NULL REFERENCES public.profiles(id) ON DELETE RESTRICT,
  order_id                  uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  booking_id                uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  transaction_type          text NOT NULL CHECK (transaction_type IN ('order', 'booking')),
  razorpay_order_id         text,
  razorpay_payment_id       text,
  amount_paise              int NOT NULL,
  currency                  text DEFAULT 'INR',
  payment_status            text NOT NULL DEFAULT 'pending'
    CHECK (payment_status IN ('pending', 'initiated', 'completed', 'failed', 'cancelled', 'refunded')),
  razorpay_response         jsonb,
  razorpay_error            jsonb,
  initiated_at              timestamptz DEFAULT now(),
  completed_at              timestamptz,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_logs_user ON public.payment_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_order ON public.payment_logs(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_booking ON public.payment_logs(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_razorpay_payment_id ON public.payment_logs(razorpay_payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_logs_status ON public.payment_logs(payment_status);

-- Auto-update updated_at on payment_logs
DROP TRIGGER IF EXISTS payment_logs_updated_at ON public.payment_logs;
CREATE TRIGGER payment_logs_updated_at
  BEFORE UPDATE ON public.payment_logs
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 4. CART TABLE (for persistent shopping cart)
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.shopping_carts (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  items             jsonb NOT NULL DEFAULT '[]',
  subtotal_paise    int NOT NULL DEFAULT 0,
  tax_paise         int NOT NULL DEFAULT 0,
  total_paise       int NOT NULL DEFAULT 0,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_shopping_carts_user ON public.shopping_carts(user_id);

DROP TRIGGER IF EXISTS shopping_carts_updated_at ON public.shopping_carts;
CREATE TRIGGER shopping_carts_updated_at
  BEFORE UPDATE ON public.shopping_carts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 5. PAYMENT REMINDER NOTIFICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.payment_reminders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  order_id            uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  booking_id          uuid REFERENCES public.bookings(id) ON DELETE CASCADE,
  transaction_type    text NOT NULL CHECK (transaction_type IN ('order', 'booking')),
  amount_due_paise    int NOT NULL,
  reminder_count      int DEFAULT 0,
  last_reminder_sent  timestamptz,
  next_reminder_at    timestamptz,
  is_resolved         boolean DEFAULT false,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_reminders_user ON public.payment_reminders(user_id);
CREATE INDEX IF NOT EXISTS idx_payment_reminders_order ON public.payment_reminders(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_reminders_booking ON public.payment_reminders(booking_id);
CREATE INDEX IF NOT EXISTS idx_payment_reminders_next_reminder ON public.payment_reminders(next_reminder_at) 
  WHERE is_resolved = false;

DROP TRIGGER IF EXISTS payment_reminders_updated_at ON public.payment_reminders;
CREATE TRIGGER payment_reminders_updated_at
  BEFORE UPDATE ON public.payment_reminders
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- =============================================================================
-- 6. ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================================================

-- Enable RLS for payment_logs
ALTER TABLE public.payment_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_logs_user_read ON public.payment_logs;
CREATE POLICY payment_logs_user_read ON public.payment_logs
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS payment_logs_admin_all ON public.payment_logs;
CREATE POLICY payment_logs_admin_all ON public.payment_logs
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- Enable RLS for shopping_carts
ALTER TABLE public.shopping_carts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shopping_carts_user_all ON public.shopping_carts;
CREATE POLICY shopping_carts_user_all ON public.shopping_carts
  FOR ALL USING (auth.uid() = user_id);

-- Enable RLS for payment_reminders
ALTER TABLE public.payment_reminders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS payment_reminders_user_read ON public.payment_reminders;
CREATE POLICY payment_reminders_user_read ON public.payment_reminders
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS payment_reminders_admin_all ON public.payment_reminders;
CREATE POLICY payment_reminders_admin_all ON public.payment_reminders
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
    )
  );

-- =============================================================================
-- 7. ADMIN STATISTICS FUNCTIONS
-- =============================================================================

-- Function to get payment statistics for admin dashboard
CREATE OR REPLACE FUNCTION get_payment_statistics(p_days_back INT DEFAULT 30)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_total_revenue_paise INT;
    v_pending_payments_paise INT;
    v_completed_payments_paise INT;
    v_failed_payments_paise INT;
    v_pending_count INT;
    v_today_revenue_paise INT;
BEGIN
    -- Get overall statistics
    SELECT 
        COALESCE(SUM(total_paise) FILTER (WHERE payment_status = 'completed'), 0),
        COALESCE(SUM(total_paise) FILTER (WHERE payment_status = 'pending'), 0),
        COALESCE(SUM(total_paise) FILTER (WHERE payment_status = 'completed'), 0),
        COALESCE(SUM(total_paise) FILTER (WHERE payment_status = 'failed'), 0),
        COUNT(*) FILTER (WHERE payment_status = 'pending'),
        COALESCE(SUM(total_paise) FILTER (WHERE payment_status = 'completed' AND DATE(created_at) = CURRENT_DATE), 0)
    INTO v_total_revenue_paise, v_pending_payments_paise, v_completed_payments_paise, 
         v_failed_payments_paise, v_pending_count, v_today_revenue_paise
    FROM public.orders
    WHERE created_at >= NOW() - INTERVAL '1 day' * p_days_back;

    v_result := jsonb_build_object(
        'total_revenue_rupees', (v_total_revenue_paise::numeric / 100)::numeric(10, 2),
        'pending_payments_rupees', (v_pending_payments_paise::numeric / 100)::numeric(10, 2),
        'completed_payments_rupees', (v_completed_payments_paise::numeric / 100)::numeric(10, 2),
        'failed_payments_rupees', (v_failed_payments_paise::numeric / 100)::numeric(10, 2),
        'pending_count', v_pending_count,
        'today_revenue_rupees', (v_today_revenue_paise::numeric / 100)::numeric(10, 2),
        'period_days', p_days_back
    );

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function to get pending payments for a user
CREATE OR REPLACE FUNCTION get_pending_payments(p_user_id UUID)
RETURNS TABLE(
    id UUID,
    amount_rupees NUMERIC,
    created_at TIMESTAMPTZ,
    payment_status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.id,
        (o.total_paise::numeric / 100)::numeric(10, 2),
        o.created_at,
        o.payment_status
    FROM public.orders o
    WHERE o.user_id = p_user_id
    AND o.payment_status IN ('pending', 'initiated', 'failed')
    ORDER BY o.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to log payment attempt
CREATE OR REPLACE FUNCTION log_payment_attempt(
    p_user_id UUID,
    p_order_id UUID,
    p_amount_paise INT,
    p_razorpay_order_id TEXT
)
RETURNS UUID AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO public.payment_logs(
        user_id,
        order_id,
        transaction_type,
        razorpay_order_id,
        amount_paise,
        payment_status,
        initiated_at
    ) VALUES (
        p_user_id,
        p_order_id,
        'order',
        p_razorpay_order_id,
        p_amount_paise,
        'initiated',
        NOW()
    ) RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update payment status after verification
CREATE OR REPLACE FUNCTION update_payment_status(
    p_order_id UUID,
    p_payment_status TEXT,
    p_razorpay_payment_id TEXT,
    p_razorpay_signature TEXT,
    p_response_data JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    v_success BOOLEAN := false;
BEGIN
    UPDATE public.orders
    SET 
        payment_status = p_payment_status,
        razorpay_payment_id = p_razorpay_payment_id,
        razorpay_signature = p_razorpay_signature,
        payment_metadata = p_response_data,
        payment_completed_at = CASE WHEN p_payment_status = 'completed' THEN NOW() ELSE payment_completed_at END,
        updated_at = NOW()
    WHERE id = p_order_id;

    IF FOUND THEN
        v_success := true;
        
        -- Update payment log (most recent entry for this order)
        UPDATE public.payment_logs
        SET 
            payment_status = p_payment_status,
            razorpay_payment_id = p_razorpay_payment_id,
            razorpay_response = p_response_data,
            completed_at = CASE WHEN p_payment_status = 'completed' THEN NOW() ELSE completed_at END,
            updated_at = NOW()
        WHERE id = (
            SELECT id FROM public.payment_logs
            WHERE order_id = p_order_id
            ORDER BY created_at DESC
            LIMIT 1
        );
    END IF;

    RETURN v_success;
END;
$$ LANGUAGE plpgsql;

-- =============================================================================
-- 8. NOTIFICATION TRIGGERS FOR PAYMENTS
-- =============================================================================

-- Function to handle payment status changes and create notifications
CREATE OR REPLACE FUNCTION handle_payment_status_change()
RETURNS TRIGGER AS $$
BEGIN
    -- When order is marked as paid, create a notification for admin (if notifications table exists)
    IF NEW.payment_status = 'completed' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'completed') THEN
        BEGIN
            INSERT INTO public.notifications(user_id, type, title, message, data)
            SELECT
                u.id,
                'payment_completed',
                'Payment Received',
                'Payment of ₹' || (NEW.total_paise::numeric / 100)::numeric(10, 2) || ' received from user',
                jsonb_build_object(
                    'order_id', NEW.id,
                    'amount_paise', NEW.total_paise,
                    'customer_id', NEW.user_id
                )
            FROM public.profiles u
            WHERE u.role = 'admin';
        EXCEPTION WHEN undefined_table THEN
            -- notifications table may not exist yet, silently continue
            NULL;
        END;
    END IF;

    -- When payment fails, create notification for user (if notifications table exists)
    IF NEW.payment_status = 'failed' AND (OLD.payment_status IS NULL OR OLD.payment_status != 'failed') THEN
        BEGIN
            INSERT INTO public.notifications(user_id, type, title, message, data)
            VALUES (
                NEW.user_id,
                'payment_failed',
                'Payment Failed',
                'Your payment of ₹' || (NEW.total_paise::numeric / 100)::numeric(10, 2) || ' failed. Please try again.',
                jsonb_build_object('order_id', NEW.id, 'amount_paise', NEW.total_paise)
            );
        EXCEPTION WHEN undefined_table THEN
            -- notifications table may not exist yet, silently continue
            NULL;
        END;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS payment_status_change ON public.orders;
CREATE TRIGGER payment_status_change
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    WHEN (OLD.payment_status IS DISTINCT FROM NEW.payment_status)
    EXECUTE FUNCTION handle_payment_status_change();

-- =============================================================================
-- 9. GRANTS AND PERMISSIONS
-- =============================================================================

GRANT SELECT, INSERT, UPDATE ON public.payment_logs TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.shopping_carts TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.payment_reminders TO authenticated;

-- Grant functions to authenticated users (with proper function signatures)
GRANT EXECUTE ON FUNCTION get_pending_payments(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION log_payment_attempt(UUID, UUID, INT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_payment_status(UUID, TEXT, TEXT, TEXT, JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_payment_statistics(INT) TO authenticated;

-- =============================================================================
-- 10. MIGRATION NOTES
-- =============================================================================

-- This migration adds comprehensive payment tracking:
-- 1. Enhanced payment status fields to orders and bookings tables
-- 2. New payment_logs table for audit trail
-- 3. New shopping_carts table for persistent cart storage
-- 4. New payment_reminders table for tracking reminder notifications
-- 5. Admin statistics functions for dashboard
-- 6. RLS policies for data security
-- 7. Triggers for automatic notifications on payment status changes

-- Migration completed successfully
