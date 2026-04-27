-- Migration: Offline Pandit Booking Marketplace
-- Description: Complete offline booking system with pandit profiles, services, reviews, availability, and booking management

-- ── Extended Pandit Profiles for Offline Services ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_pandit_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  avatar_url TEXT,
  bio TEXT,
  experience_years INTEGER DEFAULT 0,
  languages TEXT[] DEFAULT '{}',
  specialties TEXT[] DEFAULT '{}',
  rating DECIMAL(3,2) DEFAULT 0.00,
  total_reviews INTEGER DEFAULT 0,
  total_bookings INTEGER DEFAULT 0,
  base_price DECIMAL(10,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT true,
  is_verified BOOLEAN DEFAULT false,
  location_city VARCHAR(100),
  location_state VARCHAR(100),
  contact_phone VARCHAR(20),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Pandit Services ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_pandit_services (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pandit_id UUID REFERENCES offline_pandit_profiles(id) ON DELETE CASCADE,
  service_name VARCHAR(255) NOT NULL,
  description TEXT,
  duration_minutes INTEGER,
  price DECIMAL(10,2) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Pandit Availability Slots ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_pandit_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pandit_id UUID REFERENCES offline_pandit_profiles(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Pandit Reviews ─────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_pandit_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pandit_id UUID REFERENCES offline_pandit_profiles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  booking_id UUID,
  rating INTEGER CHECK (rating >= 1 AND rating <= 5) NOT NULL,
  review_text TEXT,
  is_visible BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ── Offline Bookings ────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  pandit_id UUID REFERENCES offline_pandit_profiles(id) ON DELETE CASCADE,
  service_id UUID REFERENCES offline_pandit_services(id),
  
  -- Booking details
  address_line1 VARCHAR(255) NOT NULL,
  address_line2 VARCHAR(255),
  city VARCHAR(100) NOT NULL,
  state VARCHAR(100) NOT NULL,
  pincode VARCHAR(10) NOT NULL,
  landmark VARCHAR(255),
  
  -- Schedule
  booking_date DATE NOT NULL,
  booking_time TIME NOT NULL,
  duration_minutes INTEGER DEFAULT 60,
  
  -- Service details
  service_name VARCHAR(255) NOT NULL,
  service_description TEXT,
  
  -- Pricing
  amount DECIMAL(10,2) NOT NULL,
  platform_fee DECIMAL(10,2) DEFAULT 0.00,
  pandit_payout DECIMAL(10,2) DEFAULT 0.00,
  
  -- Status
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN (
    'pending', 'accepted', 'rejected', 'paid', 'confirmed', 
    'in_progress', 'completed', 'cancelled', 'refunded'
  )),
  
  -- Payment
  is_paid BOOLEAN DEFAULT false,
  payment_id VARCHAR(255),
  payment_status VARCHAR(50) DEFAULT 'pending',
  paid_at TIMESTAMPTZ,
  
  -- Contact visibility (only after payment)
  contact_visible BOOLEAN DEFAULT false,
  pandit_contact_phone VARCHAR(20),
  
  -- Additional info
  special_requirements TEXT,
  user_notes TEXT,
  pandit_notes TEXT,
  
  -- Admin controls
  admin_notes TEXT,
  is_flagged BOOLEAN DEFAULT false,
  flag_reason TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  accepted_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ
);

-- ── Booking Status History (for audit trail) ────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS offline_booking_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES offline_bookings(id) ON DELETE CASCADE,
  old_status VARCHAR(50),
  new_status VARCHAR(50) NOT NULL,
  changed_by UUID REFERENCES auth.users(id),
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  notes TEXT
);

-- ── Indexes ─────────────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_offline_pandit_profiles_user_id ON offline_pandit_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_offline_pandit_profiles_active ON offline_pandit_profiles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_offline_pandit_profiles_city ON offline_pandit_profiles(location_city);
CREATE INDEX IF NOT EXISTS idx_offline_pandit_services_pandit_id ON offline_pandit_services(pandit_id);
CREATE INDEX IF NOT EXISTS idx_offline_pandit_availability_pandit_id ON offline_pandit_availability(pandit_id);
CREATE INDEX IF NOT EXISTS idx_offline_pandit_availability_date ON offline_pandit_availability(date);
CREATE INDEX IF NOT EXISTS idx_offline_pandit_reviews_pandit_id ON offline_pandit_reviews(pandit_id);
CREATE INDEX IF NOT EXISTS idx_offline_bookings_user_id ON offline_bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_offline_bookings_pandit_id ON offline_bookings(pandit_id);
CREATE INDEX IF NOT EXISTS idx_offline_bookings_status ON offline_bookings(status);
CREATE INDEX IF NOT EXISTS idx_offline_bookings_date ON offline_bookings(booking_date);
CREATE INDEX IF NOT EXISTS idx_offline_booking_history_booking_id ON offline_booking_status_history(booking_id);

-- ── RPC Functions ───────────────────────────────────────────────────────────────────────

-- Function to create/update pandit profile
CREATE OR REPLACE FUNCTION public.upsert_offline_pandit_profile(
  p_user_id UUID,
  p_name VARCHAR,
  p_bio TEXT,
  p_experience_years INTEGER,
  p_languages TEXT[],
  p_specialties TEXT[],
  p_base_price DECIMAL,
  p_location_city VARCHAR,
  p_location_state VARCHAR,
  p_contact_phone VARCHAR
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_profile_id UUID;
BEGIN
  INSERT INTO offline_pandit_profiles (
    user_id, name, bio, experience_years, languages, specialties, 
    base_price, location_city, location_state, contact_phone
  ) VALUES (
    p_user_id, p_name, p_bio, p_experience_years, p_languages, p_specialties,
    p_base_price, p_location_city, p_location_state, p_contact_phone
  )
  ON CONFLICT (user_id) DO UPDATE SET
    name = EXCLUDED.name,
    bio = EXCLUDED.bio,
    experience_years = EXCLUDED.experience_years,
    languages = EXCLUDED.languages,
    specialties = EXCLUDED.specialties,
    base_price = EXCLUDED.base_price,
    location_city = EXCLUDED.location_city,
    location_state = EXCLUDED.location_state,
    contact_phone = EXCLUDED.contact_phone,
    updated_at = NOW()
  RETURNING id INTO v_profile_id;
  
  RETURN v_profile_id;
END;
$$;

-- Function to search pandits with filters
CREATE OR REPLACE FUNCTION public.search_offline_pandits(
  p_city VARCHAR DEFAULT NULL,
  p_specialty VARCHAR DEFAULT NULL,
  p_min_rating DECIMAL DEFAULT NULL,
  p_max_price DECIMAL DEFAULT NULL,
  p_language VARCHAR DEFAULT NULL,
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  name VARCHAR,
  avatar_url TEXT,
  bio TEXT,
  experience_years INTEGER,
  languages TEXT[],
  specialties TEXT[],
  rating DECIMAL,
  total_reviews INTEGER,
  total_bookings INTEGER,
  base_price DECIMAL,
  location_city VARCHAR,
  location_state VARCHAR
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    op.id, op.name, op.avatar_url, op.bio, op.experience_years,
    op.languages, op.specialties, op.rating, op.total_reviews,
    op.total_bookings, op.base_price, op.location_city, op.location_state
  FROM offline_pandit_profiles op
  WHERE op.is_active = true
    AND (p_city IS NULL OR op.location_city ILIKE '%' || p_city || '%')
    AND (p_specialty IS NULL OR p_specialty = ANY(op.specialties))
    AND (p_min_rating IS NULL OR op.rating >= p_min_rating)
    AND (p_max_price IS NULL OR op.base_price <= p_max_price)
    AND (p_language IS NULL OR p_language = ANY(op.languages))
  ORDER BY op.rating DESC, op.total_bookings DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- Function to create offline booking
CREATE OR REPLACE FUNCTION public.create_offline_booking(
  p_user_id UUID,
  p_pandit_id UUID,
  p_service_id UUID,
  p_address_line1 VARCHAR,
  p_address_line2 VARCHAR,
  p_city VARCHAR,
  p_state VARCHAR,
  p_pincode VARCHAR,
  p_landmark VARCHAR,
  p_booking_date DATE,
  p_booking_time TIME,
  p_service_name VARCHAR,
  p_service_description TEXT,
  p_amount DECIMAL,
  p_special_requirements TEXT,
  p_user_notes TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking_id UUID;
  v_platform_fee DECIMAL;
  v_pandit_payout DECIMAL;
BEGIN
  -- Calculate fees (15% platform fee)
  v_platform_fee := p_amount * 0.15;
  v_pandit_payout := p_amount - v_platform_fee;
  
  INSERT INTO offline_bookings (
    user_id, pandit_id, service_id,
    address_line1, address_line2, city, state, pincode, landmark,
    booking_date, booking_time,
    service_name, service_description,
    amount, platform_fee, pandit_payout,
    special_requirements, user_notes
  ) VALUES (
    p_user_id, p_pandit_id, p_service_id,
    p_address_line1, p_address_line2, p_city, p_state, p_pincode, p_landmark,
    p_booking_date, p_booking_time,
    p_service_name, p_service_description,
    p_amount, v_platform_fee, v_pandit_payout,
    p_special_requirements, p_user_notes
  )
  RETURNING id INTO v_booking_id;
  
  -- Record status history
  INSERT INTO offline_booking_status_history (booking_id, old_status, new_status)
  VALUES (v_booking_id, NULL, 'pending');
  
  RETURN v_booking_id;
END;
$$;

-- Function for pandit to respond to booking
CREATE OR REPLACE FUNCTION public.respond_offline_booking(
  p_booking_id UUID,
  p_action VARCHAR, -- 'accept' or 'reject'
  p_pandit_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_old_status VARCHAR;
  v_new_status VARCHAR;
BEGIN
  -- Get current booking
  SELECT * INTO v_booking FROM offline_bookings WHERE id = p_booking_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;
  
  v_old_status := v_booking.status;
  
  -- Validate status
  IF v_booking.status != 'pending' THEN
    RETURN jsonb_build_object('error', 'Booking is not in pending status');
  END IF;
  
  -- Update status
  IF p_action = 'accept' THEN
    v_new_status := 'accepted';
  ELSIF p_action = 'reject' THEN
    v_new_status := 'rejected';
  ELSE
    RETURN jsonb_build_object('error', 'Invalid action');
  END IF;
  
  UPDATE offline_bookings SET
    status = v_new_status,
    pandit_notes = p_pandit_notes,
    accepted_at = CASE WHEN p_action = 'accept' THEN NOW() ELSE NULL END,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  -- Record status history
  INSERT INTO offline_booking_status_history (booking_id, old_status, new_status, notes)
  VALUES (p_booking_id, v_old_status, v_new_status, p_pandit_notes);
  
  -- Create notification for user
  INSERT INTO notifications (user_id, type, title, body, entity_type, entity_id)
  VALUES (
    v_booking.user_id,
    CASE 
      WHEN p_action = 'accept' THEN 'booking_accepted'
      ELSE 'booking_rejected'
    END,
    CASE 
      WHEN p_action = 'accept' THEN 'Booking Accepted'
      ELSE 'Booking Rejected'
    END,
    CASE 
      WHEN p_action = 'accept' THEN 'Your booking has been accepted. Please proceed with payment.'
      ELSE 'Your booking has been rejected by the pandit.'
    END,
    'offline_booking',
    p_booking_id
  );
  
  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'status', v_new_status);
END;
$$;

-- Function to mark booking as paid and reveal contact
CREATE OR REPLACE FUNCTION public.confirm_offline_booking_payment(
  p_booking_id UUID,
  p_payment_id VARCHAR
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking RECORD;
  v_pandit_phone VARCHAR;
BEGIN
  -- Get booking and pandit contact
  SELECT 
    ob.*, 
    opp.contact_phone
  INTO v_booking
  FROM offline_bookings ob
  JOIN offline_pandit_profiles opp ON ob.pandit_id = opp.id
  WHERE ob.id = p_booking_id;
  
  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'Booking not found');
  END IF;
  
  IF v_booking.status != 'accepted' THEN
    RETURN jsonb_build_object('error', 'Booking is not in accepted status');
  END IF;
  
  v_pandit_phone := v_booking.contact_phone;
  
  -- Update booking
  UPDATE offline_bookings SET
    status = 'paid',
    is_paid = true,
    payment_id = p_payment_id,
    payment_status = 'completed',
    paid_at = NOW(),
    contact_visible = true,
    pandit_contact_phone = v_pandit_phone,
    updated_at = NOW()
  WHERE id = p_booking_id;
  
  -- Record status history
  INSERT INTO offline_booking_status_history (booking_id, old_status, new_status)
  VALUES (p_booking_id, 'accepted', 'paid');
  
  -- Create notifications
  INSERT INTO notifications (user_id, type, title, body, entity_type, entity_id)
  VALUES (
    v_booking.user_id,
    'booking_confirmed',
    'Booking Confirmed',
    'Your booking has been confirmed. Pandit contact details are now visible.',
    'offline_booking',
    p_booking_id
  );
  
  INSERT INTO notifications (user_id, type, title, body, entity_type, entity_id)
  SELECT 
    user_id,
    'new_booking_confirmed',
    'New Booking Confirmed',
    'A new booking has been confirmed.',
    'offline_booking',
    p_booking_id
  FROM offline_pandit_profiles
  WHERE id = v_booking.pandit_id;
  
  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id, 'status', 'paid');
END;
$$;

-- Function to get pandit's pending bookings
CREATE OR REPLACE FUNCTION public.get_pandit_pending_bookings(p_pandit_id UUID)
RETURNS TABLE (
  id UUID,
  user_id UUID,
  user_name VARCHAR,
  address_line1 VARCHAR,
  city VARCHAR,
  booking_date DATE,
  booking_time TIME,
  service_name VARCHAR,
  amount DECIMAL,
  special_requirements TEXT,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ob.id,
    ob.user_id,
    COALESCE(p.full_name, 'User') as user_name,
    ob.address_line1,
    ob.city,
    ob.booking_date,
    ob.booking_time,
    ob.service_name,
    ob.amount,
    ob.special_requirements,
    ob.created_at
  FROM offline_bookings ob
  LEFT JOIN auth.users p ON ob.user_id = p.id
  WHERE ob.pandit_id = p_pandit_id
    AND ob.status = 'pending'
  ORDER BY ob.booking_date ASC, ob.booking_time ASC;
END;
$$;

-- Function to get user's offline bookings
CREATE OR REPLACE FUNCTION public.get_user_offline_bookings(p_user_id UUID)
RETURNS TABLE (
  id UUID,
  pandit_name VARCHAR,
  pandit_avatar TEXT,
  service_name VARCHAR,
  booking_date DATE,
  booking_time TIME,
  amount DECIMAL,
  status VARCHAR,
  is_paid BOOLEAN,
  contact_visible BOOLEAN,
  pandit_contact_phone VARCHAR,
  created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ob.id,
    opp.name as pandit_name,
    opp.avatar_url as pandit_avatar,
    ob.service_name,
    ob.booking_date,
    ob.booking_time,
    ob.amount,
    ob.status,
    ob.is_paid,
    ob.contact_visible,
    ob.pandit_contact_phone,
    ob.created_at
  FROM offline_bookings ob
  JOIN offline_pandit_profiles opp ON ob.pandit_id = opp.id
  WHERE ob.user_id = p_user_id
  ORDER BY ob.created_at DESC;
END;
$$;

-- Function to add/update pandit review
CREATE OR REPLACE FUNCTION public.upsert_pandit_review(
  p_pandit_id UUID,
  p_user_id UUID,
  p_booking_id UUID,
  p_rating INTEGER,
  p_review_text TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_review_id UUID;
BEGIN
  INSERT INTO offline_pandit_reviews (
    pandit_id, user_id, booking_id, rating, review_text
  ) VALUES (
    p_pandit_id, p_user_id, p_booking_id, p_rating, p_review_text
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_review_id;
  
  -- Update pandit rating
  UPDATE offline_pandit_profiles SET
    rating = (
      SELECT COALESCE(AVG(rating), 0) 
      FROM offline_pandit_reviews 
      WHERE pandit_id = p_pandit_id AND is_visible = true
    ),
    total_reviews = (
      SELECT COUNT(*) 
      FROM offline_pandit_reviews 
      WHERE pandit_id = p_pandit_id AND is_visible = true
    ),
    updated_at = NOW()
  WHERE id = p_pandit_id;
  
  RETURN v_review_id;
END;
$$;

-- Enable Row Level Security
ALTER TABLE offline_pandit_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_pandit_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_pandit_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_pandit_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_booking_status_history ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view active pandit profiles" ON offline_pandit_profiles
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can search pandits" ON offline_pandit_profiles
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can view pandit services" ON offline_pandit_services
  FOR SELECT USING (is_active = true);

CREATE POLICY "Users can view pandit availability" ON offline_pandit_availability
  FOR SELECT USING (is_available = true);

CREATE POLICY "Users can view visible reviews" ON offline_pandit_reviews
  FOR SELECT USING (is_visible = true);

CREATE POLICY "Users can view own bookings" ON offline_bookings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Pandits can view their bookings" ON offline_bookings
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM offline_pandit_profiles 
      WHERE id = pandit_id AND user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create bookings" ON offline_bookings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can insert reviews" ON offline_pandit_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Grant execute permissions on RPC functions
GRANT EXECUTE ON FUNCTION public.upsert_offline_pandit_profile TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_offline_pandits TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_offline_booking TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_offline_booking TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_offline_booking_payment TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_pandit_pending_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_offline_bookings TO authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_pandit_review TO authenticated;
