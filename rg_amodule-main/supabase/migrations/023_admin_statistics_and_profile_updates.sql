-- Migration: Admin Statistics and Profile Updates
-- Description: Adds offline_booking_enabled field and statistics RPC functions

-- ── 1. Add offline_booking_enabled to pandit_details table ─────────────────────

-- Check if column exists, if not add it
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'pandit_details' 
        AND column_name = 'offline_booking_enabled'
    ) THEN
        ALTER TABLE pandit_details 
        ADD COLUMN offline_booking_enabled BOOLEAN DEFAULT true;
        
        -- Update existing records to have the default value
        UPDATE pandit_details 
        SET offline_booking_enabled = true 
        WHERE offline_booking_enabled IS NULL;
        
        RAISE NOTICE 'Added offline_booking_enabled column to pandit_details';
    ELSE
        RAISE NOTICE 'offline_booking_enabled column already exists';
    END IF;
END $$;

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_pandit_details_offline_booking_enabled 
ON pandit_details(offline_booking_enabled) 
WHERE offline_booking_enabled = true;

-- ── 2. Statistics Functions for Pandits ───────────────────────────────────────

-- Function to get booking statistics for a specific pandit
CREATE OR REPLACE FUNCTION get_pandit_booking_stats(p_pandit_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_total_bookings INT;
    v_completed_bookings INT;
    v_cancelled_bookings INT;
    v_pending_bookings INT;
    v_pandit_name TEXT;
    v_current_month INT;
    v_current_year INT;
    v_current_week INT;
BEGIN
    -- Get current date info
    v_current_month := EXTRACT(MONTH FROM CURRENT_DATE);
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    v_current_week := EXTRACT(WEEK FROM CURRENT_DATE);
    
    -- Get pandit name
    SELECT name INTO v_pandit_name
    FROM pandit_details
    WHERE id = p_pandit_id;
    
    -- Get overall statistics
    SELECT 
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE status = 'completed')::INT,
        COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
        COUNT(*) FILTER (WHERE status = 'pending')::INT
    INTO v_total_bookings, v_completed_bookings, v_cancelled_bookings, v_pending_bookings
    FROM offline_bookings
    WHERE pandit_id = p_pandit_id;
    
    -- Build result JSON
    v_result := jsonb_build_object(
        'pandit_id', p_pandit_id,
        'pandit_name', COALESCE(v_pandit_name, 'Unknown'),
        'statistics', jsonb_build_object(
            'total_bookings', v_total_bookings,
            'completed_bookings', v_completed_bookings,
            'cancelled_bookings', v_cancelled_bookings,
            'pending_bookings', v_pending_bookings,
            'monthly_stats', (
                SELECT jsonb_build_object(
                    'month', v_current_month,
                    'year', v_current_year,
                    'total_bookings', COUNT(*)::INT,
                    'completed_bookings', COUNT(*) FILTER (WHERE status = 'completed')::INT,
                    'cancelled_bookings', COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
                    'pending_bookings', COUNT(*) FILTER (WHERE status = 'pending')::INT
                )
                FROM offline_bookings
                WHERE pandit_id = p_pandit_id
                AND EXTRACT(MONTH FROM created_at) = v_current_month
                AND EXTRACT(YEAR FROM created_at) = v_current_year
            ),
            'weekly_stats', (
                SELECT jsonb_build_object(
                    'week_number', v_current_week,
                    'year', v_current_year,
                    'total_bookings', COUNT(*)::INT,
                    'completed_bookings', COUNT(*) FILTER (WHERE status = 'completed')::INT,
                    'cancelled_bookings', COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
                    'pending_bookings', COUNT(*) FILTER (WHERE status = 'pending')::INT
                )
                FROM offline_bookings
                WHERE pandit_id = p_pandit_id
                AND EXTRACT(WEEK FROM created_at) = v_current_week
                AND EXTRACT(YEAR FROM created_at) = v_current_year
            )
        )
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all pandits statistics
CREATE OR REPLACE FUNCTION get_all_pandits_stats()
RETURNS JSONB[] AS $$
DECLARE
    v_pandit_ids UUID[];
    v_result JSONB[] := ARRAY[]::JSONB[];
    v_pandit_id UUID;
    v_stats JSONB;
BEGIN
    -- Get all pandit IDs
    SELECT ARRAY_AGG(id) INTO v_pandit_ids
    FROM pandit_details
    WHERE is_active = true;
    
    -- Get stats for each pandit
    FOREACH v_pandit_id IN ARRAY v_pandit_ids
    LOOP
        v_stats := get_pandit_booking_stats(v_pandit_id);
        v_result := array_append(v_result, v_stats);
    END LOOP;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 3. Statistics Functions for Users ───────────────────────────────────────

-- Function to get booking statistics for a specific user
CREATE OR REPLACE FUNCTION get_user_booking_stats(p_user_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_total_bookings INT;
    v_completed_bookings INT;
    v_cancelled_bookings INT;
    v_pending_bookings INT;
    v_user_name TEXT;
    v_current_month INT;
    v_current_year INT;
    v_current_week INT;
BEGIN
    -- Get current date info
    v_current_month := EXTRACT(MONTH FROM CURRENT_DATE);
    v_current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    v_current_week := EXTRACT(WEEK FROM CURRENT_DATE);
    
    -- Get user name
    SELECT raw_user_meta_info->>'name' INTO v_user_name
    FROM auth.users
    WHERE id = p_user_id;
    
    -- Get overall statistics
    SELECT 
        COUNT(*)::INT,
        COUNT(*) FILTER (WHERE status = 'completed')::INT,
        COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
        COUNT(*) FILTER (WHERE status = 'pending')::INT
    INTO v_total_bookings, v_completed_bookings, v_cancelled_bookings, v_pending_bookings
    FROM offline_bookings
    WHERE user_id = p_user_id;
    
    -- Build result JSON
    v_result := jsonb_build_object(
        'user_id', p_user_id,
        'user_name', COALESCE(v_user_name, 'Unknown'),
        'statistics', jsonb_build_object(
            'total_bookings', v_total_bookings,
            'completed_bookings', v_completed_bookings,
            'cancelled_bookings', v_cancelled_bookings,
            'pending_bookings', v_pending_bookings,
            'monthly_stats', (
                SELECT jsonb_build_object(
                    'month', v_current_month,
                    'year', v_current_year,
                    'total_bookings', COUNT(*)::INT,
                    'completed_bookings', COUNT(*) FILTER (WHERE status = 'completed')::INT,
                    'cancelled_bookings', COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
                    'pending_bookings', COUNT(*) FILTER (WHERE status = 'pending')::INT
                )
                FROM offline_bookings
                WHERE user_id = p_user_id
                AND EXTRACT(MONTH FROM created_at) = v_current_month
                AND EXTRACT(YEAR FROM created_at) = v_current_year
            ),
            'weekly_stats', (
                SELECT jsonb_build_object(
                    'week_number', v_current_week,
                    'year', v_current_year,
                    'total_bookings', COUNT(*)::INT,
                    'completed_bookings', COUNT(*) FILTER (WHERE status = 'completed')::INT,
                    'cancelled_bookings', COUNT(*) FILTER (WHERE status = 'cancelled')::INT,
                    'pending_bookings', COUNT(*) FILTER (WHERE status = 'pending')::INT
                )
                FROM offline_bookings
                WHERE user_id = p_user_id
                AND EXTRACT(WEEK FROM created_at) = v_current_week
                AND EXTRACT(YEAR FROM created_at) = v_current_year
            )
        )
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all users statistics
CREATE OR REPLACE FUNCTION get_all_users_stats()
RETURNS JSONB[] AS $$
DECLARE
    v_user_ids UUID[];
    v_result JSONB[] := ARRAY[]::JSONB[];
    v_user_id UUID;
    v_stats JSONB;
BEGIN
    -- Get all user IDs who have made bookings
    SELECT ARRAY_AGG(DISTINCT user_id) INTO v_user_ids
    FROM offline_bookings;
    
    -- Get stats for each user
    FOREACH v_user_id IN ARRAY v_user_ids
    LOOP
        v_stats := get_user_booking_stats(v_user_id);
        v_result := array_append(v_result, v_stats);
    END LOOP;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 4. Admin Helper Functions ────────────────────────────────────────────────

-- Function to update offline booking status (admin only)
CREATE OR REPLACE FUNCTION admin_update_offline_booking_status(
    p_booking_id UUID,
    p_new_status TEXT,
    p_admin_notes TEXT DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE offline_bookings
    SET 
        status = p_new_status,
        admin_notes = COALESCE(p_admin_notes, admin_notes),
        updated_at = NOW()
    WHERE id = p_booking_id;
    
    v_result := jsonb_build_object(
        'success', TRUE,
        'booking_id', p_booking_id,
        'new_status', p_new_status
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process refund (admin only)
CREATE OR REPLACE FUNCTION admin_process_offline_refund(
    p_booking_id UUID,
    p_reason TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE offline_bookings
    SET 
        status = 'refunded',
        refund_reason = p_reason,
        refund_processed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_booking_id
    AND status = 'cancelled';
    
    IF FOUND THEN
        v_result := jsonb_build_object(
            'success', TRUE,
            'booking_id', p_booking_id,
            'status', 'refunded'
        );
    ELSE
        v_result := jsonb_build_object(
            'success', FALSE,
            'error', 'Booking not found or not in cancelled status'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process payout to pandit (admin only)
CREATE OR REPLACE FUNCTION admin_process_offline_payout(
    p_booking_id UUID
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_pandit_id UUID;
    v_amount DECIMAL;
BEGIN
    -- Get booking details
    SELECT pandit_id, pandit_payout_amount 
    INTO v_pandit_id, v_amount
    FROM offline_bookings
    WHERE id = p_booking_id;
    
    -- Update booking status
    UPDATE offline_bookings
    SET 
        status = 'completed',
        payout_processed_at = NOW(),
        updated_at = NOW()
    WHERE id = p_booking_id
    AND status = 'payment_confirmed';
    
    IF FOUND THEN
        v_result := jsonb_build_object(
            'success', TRUE,
            'booking_id', p_booking_id,
            'pandit_id', v_pandit_id,
            'payout_amount', v_amount,
            'status', 'completed'
        );
    ELSE
        v_result := jsonb_build_object(
            'success', FALSE,
            'error', 'Booking not found or not in payment_confirmed status'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ── 5. Row Level Security Policies ────────────────────────────────────────────

-- Ensure RLS is enabled on offline_bookings
ALTER TABLE offline_bookings ENABLE ROW LEVEL SECURITY;

-- Policy for admins to view all bookings
DROP POLICY IF EXISTS "Admins can view all offline bookings" ON offline_bookings;
CREATE POLICY "Admins can view all offline bookings"
ON offline_bookings FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- Policy for admins to update all bookings
DROP POLICY IF EXISTS "Admins can update all offline bookings" ON offline_bookings;
CREATE POLICY "Admins can update all offline bookings"
ON offline_bookings FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM profiles
        WHERE id = auth.uid()
        AND role = 'admin'
    )
);

-- ── 6. Grant Permissions ────────────────────────────────────────────────────

GRANT EXECUTE ON FUNCTION get_pandit_booking_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_pandits_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_booking_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_users_stats() TO authenticated;
GRANT EXECUTE ON FUNCTION admin_update_offline_booking_status(UUID, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_offline_refund(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_process_offline_payout(UUID) TO authenticated;

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO authenticated;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

COMMENT ON FUNCTION get_pandit_booking_stats IS 'Returns booking statistics for a specific pandit including monthly and weekly breakdowns';
COMMENT ON FUNCTION get_all_pandits_stats IS 'Returns booking statistics for all active pandits';
COMMENT ON FUNCTION get_user_booking_stats IS 'Returns booking statistics for a specific user including monthly and weekly breakdowns';
COMMENT ON FUNCTION get_all_users_stats IS 'Returns booking statistics for all users who have made bookings';
