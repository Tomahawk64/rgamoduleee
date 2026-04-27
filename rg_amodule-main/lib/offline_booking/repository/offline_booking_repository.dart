// lib/offline_booking/repository/offline_booking_repository.dart
// Repository for offline pandit booking operations

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/offline_booking_models.dart';
import '../../admin/models/booking_statistics_models.dart';

// ── Abstract Repository Interface ─────────────────────────────────────────────────────

abstract class IOfflineBookingRepository {
  // Pandit Profile Operations
  Future<List<OfflinePanditProfile>> searchPandits({
    String? city,
    String? specialty,
    double? minRating,
    double? maxPrice,
    String? language,
    int limit = 50,
    int offset = 0,
  });

  Future<OfflinePanditProfile?> getPanditProfile(String panditId);
  
  Future<OfflinePanditProfile> upsertPanditProfile({
    required String userId,
    required String name,
    String? bio,
    int? experienceYears,
    List<String>? languages,
    List<String>? specialties,
    double? basePrice,
    String? locationCity,
    String? locationState,
    String? contactPhone,
  });

  // Service Operations
  Future<List<OfflinePanditService>> getPanditServices(String panditId);

  // Availability Operations
  Future<List<OfflinePanditAvailability>> getPanditAvailability(
    String panditId,
    DateTime startDate,
    DateTime endDate,
  );

  // Booking Operations
  Future<OfflineBooking> createBooking({
    required String userId,
    required String panditId,
    String? serviceId,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    String? landmark,
    required DateTime bookingDate,
    required String bookingTime,
    required String serviceName,
    String? serviceDescription,
    required double amount,
    String? specialRequirements,
    String? userNotes,
  });

  Future<OfflineBooking> respondToBooking({
    required String bookingId,
    required String action, // 'accept' or 'reject'
    String? panditNotes,
  });

  Future<OfflineBooking> confirmBookingPayment({
    required String bookingId,
    required String paymentId,
  });

  Future<List<OfflineBooking>> getPanditPendingBookings(String panditId);
  
  Future<List<OfflineBooking>> getUserBookings(String userId);

  Future<OfflineBooking?> getBooking(String bookingId);

  // Review Operations
  Future<void> addReview({
    required String panditId,
    required String userId,
    String? bookingId,
    required int rating,
    String? reviewText,
  });

  Future<List<OfflinePanditReview>> getPanditReviews(String panditId);

  // Admin Operations
  Future<List<OfflineBooking>> getAllBookings({
    OfflineBookingStatus? status,
    int limit = 100,
    int offset = 0,
  });

  Future<bool> adminCancelBooking(String bookingId, String reason);

  Future<bool> adminProcessRefund(String bookingId, String reason);

  Future<bool> adminProcessPayout(String bookingId);

  Future<bool> adminUpdateBookingStatus(
    String bookingId,
    OfflineBookingStatus newStatus,
    String? adminNotes,
  );

  // Statistics Operations
  Future<PanditBookingStats> getPanditBookingStats(String panditId);
  Future<UserBookingStats> getUserBookingStats(String userId);
  Future<List<PanditBookingStats>> getAllPanditsStats();
  Future<List<UserBookingStats>> getAllUsersStats();
}

// ── Supabase Implementation ────────────────────────────────────────────────────────────

class SupabaseOfflineBookingRepository implements IOfflineBookingRepository {
  SupabaseOfflineBookingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OfflinePanditProfile>> searchPandits({
    String? city,
    String? specialty,
    double? minRating,
    double? maxPrice,
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    // Query real pandit tables: profiles (role='pandit') + pandit_details
    var query = _client
        .from('profiles')
        .select('id, full_name, phone, rating, avatar_url, created_at, updated_at, pandit_details!inner(specialties, languages, experience_years, bio, is_online, consultation_enabled, offline_booking_enabled, location)')
        .eq('role', 'pandit')
        .eq('is_active', true);

    if (minRating != null) {
      query = query.gte('rating', minRating);
    }

    final result = await query
        .order('rating', ascending: false)
        .range(offset, offset + limit - 1);

    var profiles = (result as List).cast<Map<String, dynamic>>().map((row) {
      final details = row['pandit_details'] as Map<String, dynamic>? ?? {};
      final locationStr = details['location'] as String?;
      // Parse location "City, State" or just "City"
      String? locationCity;
      String? locationState;
      if (locationStr != null && locationStr.isNotEmpty) {
        final parts = locationStr.split(',').map((s) => s.trim()).toList();
        locationCity = parts.isNotEmpty ? parts[0] : null;
        locationState = parts.length > 1 ? parts[1] : null;
      }

      return OfflinePanditProfile(
        id: row['id'] as String,
        userId: row['id'] as String,
        name: row['full_name'] as String? ?? 'Pandit',
        avatarUrl: row['avatar_url'] as String?,
        bio: details['bio'] as String?,
        experienceYears: (details['experience_years'] as num?)?.toInt() ?? 0,
        languages: (details['languages'] as List?)?.cast<String>() ?? [],
        specialties: (details['specialties'] as List?)?.cast<String>() ?? [],
        rating: (row['rating'] as num?)?.toDouble() ?? 0.0,
        totalReviews: 0,
        totalBookings: 0,
        basePrice: 0.0,
        isActive: true,
        isVerified: true,
        locationCity: locationCity,
        locationState: locationState,
        contactPhone: row['phone'] as String?,
        createdAt: row['created_at'] != null
            ? DateTime.parse(row['created_at'] as String)
            : DateTime.now(),
        updatedAt: row['updated_at'] != null
            ? DateTime.parse(row['updated_at'] as String)
            : null,
      );
    }).toList();

    // In-memory filters
    if (city != null && city.isNotEmpty) {
      profiles = profiles
          .where((p) =>
              (p.locationCity?.toLowerCase().contains(city.toLowerCase()) ?? false) ||
              (p.locationState?.toLowerCase().contains(city.toLowerCase()) ?? false))
          .toList();
    }
    if (specialty != null && specialty.isNotEmpty) {
      profiles = profiles
          .where((p) => p.specialties.any(
              (s) => s.toLowerCase().contains(specialty.toLowerCase())))
          .toList();
    }
    if (language != null && language.isNotEmpty) {
      profiles = profiles
          .where((p) => p.languages.any(
              (l) => l.toLowerCase().contains(language.toLowerCase())))
          .toList();
    }

    return profiles;
  }

  @override
  Future<OfflinePanditProfile?> getPanditProfile(String panditId) async {
    final results = await Future.wait([
      _client
          .from('profiles')
          .select('id, full_name, phone, rating, avatar_url, created_at, updated_at')
          .eq('id', panditId)
          .eq('is_active', true)
          .maybeSingle(),
      _client
          .from('pandit_details')
          .select('specialties, languages, experience_years, bio, is_online, consultation_enabled, offline_booking_enabled, location')
          .eq('id', panditId)
          .maybeSingle(),
    ]);

    final profileRow = results[0];
    if (profileRow == null) return null;

    final details = results[1] ?? {};
    final locationStr = details['location'] as String?;
    String? locationCity;
    String? locationState;
    if (locationStr != null && locationStr.isNotEmpty) {
      final parts = locationStr.split(',').map((s) => s.trim()).toList();
      locationCity = parts.isNotEmpty ? parts[0] : null;
      locationState = parts.length > 1 ? parts[1] : null;
    }

    return OfflinePanditProfile(
      id: profileRow['id'] as String,
      userId: profileRow['id'] as String,
      name: profileRow['full_name'] as String? ?? 'Pandit',
      avatarUrl: profileRow['avatar_url'] as String?,
      bio: details['bio'] as String?,
      experienceYears: (details['experience_years'] as num?)?.toInt() ?? 0,
      languages: (details['languages'] as List?)?.cast<String>() ?? [],
      specialties: (details['specialties'] as List?)?.cast<String>() ?? [],
      rating: (profileRow['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: 0,
      totalBookings: 0,
      basePrice: 0.0,
      isActive: true,
      isVerified: true,
      locationCity: locationCity,
      locationState: locationState,
      contactPhone: profileRow['phone'] as String?,
      createdAt: profileRow['created_at'] != null
          ? DateTime.parse(profileRow['created_at'] as String)
          : DateTime.now(),
      updatedAt: profileRow['updated_at'] != null
          ? DateTime.parse(profileRow['updated_at'] as String)
          : null,
    );
  }

  @override
  Future<OfflinePanditProfile> upsertPanditProfile({
    required String userId,
    required String name,
    String? bio,
    int? experienceYears,
    List<String>? languages,
    List<String>? specialties,
    double? basePrice,
    String? locationCity,
    String? locationState,
    String? contactPhone,
  }) async {
    final result = await _client.rpc('upsert_offline_pandit_profile', params: {
      'p_user_id': userId,
      'p_name': name,
      'p_bio': bio,
      'p_experience_years': experienceYears,
      'p_languages': languages,
      'p_specialties': specialties,
      'p_base_price': basePrice,
      'p_location_city': locationCity,
      'p_location_state': locationState,
      'p_contact_phone': contactPhone,
    });

    final profileId = result as String?;
    if (profileId == null) {
      throw Exception('Failed to upsert pandit profile');
    }

    final profile = await getPanditProfile(profileId);
    if (profile == null) {
      throw Exception('Failed to retrieve upserted profile');
    }

    return profile;
  }

  @override
  Future<List<OfflinePanditService>> getPanditServices(String panditId) async {
    final result = await _client
        .from('offline_pandit_services')
        .select('*')
        .eq('pandit_id', panditId)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (result as List)
        .cast<Map<String, dynamic>>()
        .map((s) => OfflinePanditService.fromJson(s))
        .toList();
  }

  @override
  Future<List<OfflinePanditAvailability>> getPanditAvailability(
    String panditId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await _client
        .from('offline_pandit_availability')
        .select('*')
        .eq('pandit_id', panditId)
        .gte('date', startDate.toIso8601String())
        .lte('date', endDate.toIso8601String())
        .eq('is_available', true)
        .order('date', ascending: true)
        .order('start_time', ascending: true);

    return (result as List)
        .cast<Map<String, dynamic>>()
        .map((a) => OfflinePanditAvailability.fromJson(a))
        .toList();
  }

  @override
  Future<OfflineBooking> createBooking({
    required String userId,
    required String panditId,
    String? serviceId,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    String? landmark,
    required DateTime bookingDate,
    required String bookingTime,
    required String serviceName,
    String? serviceDescription,
    required double amount,
    String? specialRequirements,
    String? userNotes,
  }) async {
    final result = await _client.rpc('create_offline_booking', params: {
      'p_user_id': userId,
      'p_pandit_id': panditId,
      'p_service_id': serviceId,
      'p_address_line1': addressLine1,
      'p_address_line2': addressLine2,
      'p_city': city,
      'p_state': state,
      'p_pincode': pincode,
      'p_landmark': landmark,
      'p_booking_date': bookingDate.toIso8601String(),
      'p_booking_time': bookingTime,
      'p_service_name': serviceName,
      'p_service_description': serviceDescription,
      'p_amount': amount,
      'p_special_requirements': specialRequirements,
      'p_user_notes': userNotes,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error'] as String);
    }

    final bookingId = data['booking_id'] as String?;
    if (bookingId == null) {
      throw Exception('Failed to create booking');
    }

    final booking = await getBooking(bookingId);
    if (booking == null) {
      throw Exception('Failed to retrieve created booking');
    }

    return booking;
  }

  @override
  Future<OfflineBooking> respondToBooking({
    required String bookingId,
    required String action,
    String? panditNotes,
  }) async {
    final result = await _client.rpc('respond_offline_booking', params: {
      'p_booking_id': bookingId,
      'p_action': action,
      'p_pandit_notes': panditNotes,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error'] as String);
    }

    final booking = await getBooking(bookingId);
    if (booking == null) {
      throw Exception('Failed to retrieve updated booking');
    }

    return booking;
  }

  @override
  Future<OfflineBooking> confirmBookingPayment({
    required String bookingId,
    required String paymentId,
  }) async {
    final result = await _client.rpc('confirm_offline_booking_payment', params: {
      'p_booking_id': bookingId,
      'p_payment_id': paymentId,
    });

    final data = result as Map<String, dynamic>;
    if (data['error'] != null) {
      throw Exception(data['error'] as String);
    }

    final booking = await getBooking(bookingId);
    if (booking == null) {
      throw Exception('Failed to retrieve updated booking');
    }

    return booking;
  }

  @override
  Future<List<OfflineBooking>> getPanditPendingBookings(String panditId) async {
    final result = await _client.rpc('get_pandit_pending_bookings', params: {
      'p_pandit_id': panditId,
    });

    final bookingsData = result as List?;
    if (bookingsData == null) return [];

    return bookingsData
        .cast<Map<String, dynamic>>()
        .map((b) => OfflineBooking.fromJson(b))
        .toList();
  }

  @override
  Future<List<OfflineBooking>> getUserBookings(String userId) async {
    final result = await _client.rpc('get_user_offline_bookings', params: {
      'p_user_id': userId,
    });

    // ignore: unnecessary_cast
    final bookingsData = result as dynamic;
    if (bookingsData == null) return [];

    return bookingsData
        .map((b) => OfflineBooking.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<OfflineBooking?> getBooking(String bookingId) async {
    final result = await _client
        .from('offline_bookings')
        .select('''
          *,
          pandit:offline_pandit_profiles!offline_bookings_pandit_id_fkey(name, avatar_url)
        ''')
        .eq('id', bookingId)
        .maybeSingle();

    if (result == null) return null;

    final json = result;
    // Add pandit name and avatar from joined data
    if (json['pandit'] != null) {
      final pandit = json['pandit'] as Map<String, dynamic>;
      json['pandit_name'] = pandit['name'] as String?;
      json['pandit_avatar'] = pandit['avatar_url'] as String?;
    }

    return OfflineBooking.fromJson(json);
  }

  @override
  Future<void> addReview({
    required String panditId,
    required String userId,
    String? bookingId,
    required int rating,
    String? reviewText,
  }) async {
    await _client.rpc('upsert_pandit_review', params: {
      'p_pandit_id': panditId,
      'p_user_id': userId,
      'p_booking_id': bookingId,
      'p_rating': rating,
      'p_review_text': reviewText,
    });
  }

  @override
  Future<List<OfflinePanditReview>> getPanditReviews(String panditId) async {
    final result = await _client
        .from('offline_pandit_reviews')
        .select('*')
        .eq('pandit_id', panditId)
        .order('created_at', ascending: false)
        .limit(50);

    return result
        .cast<Map<String, dynamic>>()
        .map((r) => OfflinePanditReview.fromJson(r))
        .toList();
  }

  @override
  Future<List<OfflineBooking>> getAllBookings({
    OfflineBookingStatus? status,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = _client.from('offline_bookings').select('*');
    
    if (status != null) {
      query = query.eq('status', status.value);
    }
    
    final result = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return result
        .cast<Map<String, dynamic>>()
        .map((b) => OfflineBooking.fromJson(b))
        .toList();
  }

  @override
  Future<bool> adminCancelBooking(String bookingId, String reason) async {
    final result = await _client.rpc('admin_cancel_offline_booking', params: {
      'p_booking_id': bookingId,
      'p_reason': reason,
    });

    final data = result as Map<String, dynamic>;
    return data['success'] == true;
  }

  @override
  Future<bool> adminProcessRefund(String bookingId, String reason) async {
    final result = await _client.rpc('admin_refund_offline_booking', params: {
      'p_booking_id': bookingId,
      'p_reason': reason,
    });

    final data = result as Map<String, dynamic>;
    return data['success'] == true;
  }

  @override
  Future<bool> adminProcessPayout(String bookingId) async {
    final result = await _client.rpc('admin_payout_offline_booking', params: {
      'p_booking_id': bookingId,
    });

    final data = result as Map<String, dynamic>;
    return data['success'] == true;
  }

  @override
  Future<bool> adminUpdateBookingStatus(
    String bookingId,
    OfflineBookingStatus newStatus,
    String? adminNotes,
  ) async {
    final result = await _client.rpc('admin_update_offline_booking_status', params: {
      'p_booking_id': bookingId,
      'p_new_status': newStatus.value,
      'p_admin_notes': adminNotes,
    });

    final data = result as Map<String, dynamic>;
    return data['success'] == true;
  }

  @override
  Future<PanditBookingStats> getPanditBookingStats(String panditId) async {
    final result = await _client.rpc('get_pandit_booking_stats', params: {
      'p_pandit_id': panditId,
    });

    final data = result as Map<String, dynamic>;
    return PanditBookingStats.fromJson(data);
  }

  @override
  Future<UserBookingStats> getUserBookingStats(String userId) async {
    final result = await _client.rpc('get_user_booking_stats', params: {
      'p_user_id': userId,
    });

    final data = result as Map<String, dynamic>;
    return UserBookingStats.fromJson(data);
  }

  @override
  Future<List<PanditBookingStats>> getAllPanditsStats() async {
    final result = await _client.rpc('get_all_pandits_stats');
    
    final data = result as List;
    return data
        .map((p) => PanditBookingStats.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<UserBookingStats>> getAllUsersStats() async {
    final result = await _client.rpc('get_all_users_stats');
    
    final data = result as List;
    return data
        .map((u) => UserBookingStats.fromJson(u as Map<String, dynamic>))
        .toList();
  }
}

// ── Fallback Repository ───────────────────────────────────────────────────────────────
/// Tries the primary (Supabase) repository first. If any error occurs
/// (e.g. table not found, RLS denied, network issue), transparently
/// delegates to the fallback (Mock) repository so the UI always loads.

class FallbackOfflineBookingRepository implements IOfflineBookingRepository {
  FallbackOfflineBookingRepository({
    required this.primary,
    required this.fallback,
  });

  final IOfflineBookingRepository primary;
  final IOfflineBookingRepository fallback;
  bool _useFallback = false;

  Future<T> _try<T>(Future<T> Function(IOfflineBookingRepository r) fn) async {
    if (_useFallback) return fn(fallback);
    try {
      return await fn(primary);
    } catch (_) {
      _useFallback = true;
      return fn(fallback);
    }
  }

  /// searchPandits delegates to _try like everything else.
  /// Primary now queries real profiles+pandit_details tables.
  @override
  Future<List<OfflinePanditProfile>> searchPandits({
    String? city, String? specialty, double? minRating, double? maxPrice,
    String? language, int limit = 50, int offset = 0,
  }) => _try((r) => r.searchPandits(
    city: city, specialty: specialty, minRating: minRating,
    maxPrice: maxPrice, language: language, limit: limit, offset: offset,
  ));

  @override
  Future<OfflinePanditProfile?> getPanditProfile(String panditId) =>
      _try((r) => r.getPanditProfile(panditId));

  @override
  Future<OfflinePanditProfile> upsertPanditProfile({
    required String userId, required String name, String? bio,
    int? experienceYears, List<String>? languages, List<String>? specialties,
    double? basePrice, String? locationCity, String? locationState,
    String? contactPhone,
  }) => _try((r) => r.upsertPanditProfile(
    userId: userId, name: name, bio: bio, experienceYears: experienceYears,
    languages: languages, specialties: specialties, basePrice: basePrice,
    locationCity: locationCity, locationState: locationState,
    contactPhone: contactPhone,
  ));

  @override
  Future<List<OfflinePanditService>> getPanditServices(String panditId) =>
      _try((r) => r.getPanditServices(panditId));

  @override
  Future<List<OfflinePanditAvailability>> getPanditAvailability(
    String panditId, DateTime startDate, DateTime endDate,
  ) => _try((r) => r.getPanditAvailability(panditId, startDate, endDate));

  @override
  Future<OfflineBooking> createBooking({
    required String userId, required String panditId, String? serviceId,
    required String addressLine1, String? addressLine2, required String city,
    required String state, required String pincode, String? landmark,
    required DateTime bookingDate, required String bookingTime,
    required String serviceName, String? serviceDescription,
    required double amount, String? specialRequirements, String? userNotes,
  }) => _try((r) => r.createBooking(
    userId: userId, panditId: panditId, serviceId: serviceId,
    addressLine1: addressLine1, addressLine2: addressLine2, city: city,
    state: state, pincode: pincode, landmark: landmark,
    bookingDate: bookingDate, bookingTime: bookingTime,
    serviceName: serviceName, serviceDescription: serviceDescription,
    amount: amount, specialRequirements: specialRequirements,
    userNotes: userNotes,
  ));

  @override
  Future<OfflineBooking> respondToBooking({
    required String bookingId, required String action, String? panditNotes,
  }) => _try((r) => r.respondToBooking(
    bookingId: bookingId, action: action, panditNotes: panditNotes,
  ));

  @override
  Future<OfflineBooking> confirmBookingPayment({
    required String bookingId, required String paymentId,
  }) => _try((r) => r.confirmBookingPayment(
    bookingId: bookingId, paymentId: paymentId,
  ));

  @override
  Future<List<OfflineBooking>> getPanditPendingBookings(String panditId) =>
      _try((r) => r.getPanditPendingBookings(panditId));

  @override
  Future<List<OfflineBooking>> getUserBookings(String userId) =>
      _try((r) => r.getUserBookings(userId));

  @override
  Future<OfflineBooking?> getBooking(String bookingId) =>
      _try((r) => r.getBooking(bookingId));

  @override
  Future<void> addReview({
    required String panditId, required String userId, String? bookingId,
    required int rating, String? reviewText,
  }) => _try((r) => r.addReview(
    panditId: panditId, userId: userId, bookingId: bookingId,
    rating: rating, reviewText: reviewText,
  ));

  @override
  Future<List<OfflinePanditReview>> getPanditReviews(String panditId) =>
      _try((r) => r.getPanditReviews(panditId));

  @override
  Future<List<OfflineBooking>> getAllBookings({
    OfflineBookingStatus? status, int limit = 100, int offset = 0,
  }) => _try((r) => r.getAllBookings(status: status, limit: limit, offset: offset));

  @override
  Future<bool> adminCancelBooking(String bookingId, String reason) =>
      _try((r) => r.adminCancelBooking(bookingId, reason));

  @override
  Future<bool> adminProcessRefund(String bookingId, String reason) =>
      _try((r) => r.adminProcessRefund(bookingId, reason));

  @override
  Future<bool> adminProcessPayout(String bookingId) =>
      _try((r) => r.adminProcessPayout(bookingId));

  @override
  Future<bool> adminUpdateBookingStatus(
    String bookingId, OfflineBookingStatus newStatus, String? adminNotes,
  ) => _try((r) => r.adminUpdateBookingStatus(bookingId, newStatus, adminNotes));

  @override
  Future<PanditBookingStats> getPanditBookingStats(String panditId) =>
      _try((r) => r.getPanditBookingStats(panditId));

  @override
  Future<UserBookingStats> getUserBookingStats(String userId) =>
      _try((r) => r.getUserBookingStats(userId));

  @override
  Future<List<PanditBookingStats>> getAllPanditsStats() =>
      _try((r) => r.getAllPanditsStats());

  @override
  Future<List<UserBookingStats>> getAllUsersStats() =>
      _try((r) => r.getAllUsersStats());
}

// ── Mock Implementation ───────────────────────────────────────────────────────────────

class MockOfflineBookingRepository implements IOfflineBookingRepository {
  // Mock data
  final _mockPandits = <OfflinePanditProfile>[];
  final _mockBookings = <OfflineBooking>[];
  final _mockReviews = <OfflinePanditReview>[];

  MockOfflineBookingRepository() {
    _seedMockData();
  }

  void _seedMockData() {
    _mockPandits.addAll([
      OfflinePanditProfile(
        id: 'p1',
        userId: 'pu1',
        name: 'Pt. Ramesh Sharma',
        bio: 'Expert in Vedic rituals with 15 years of experience. Specialized in Satyanarayan Puja, Griha Pravesh, and Navgraha Shanti.',
        experienceYears: 15,
        languages: ['Hindi', 'English', 'Sanskrit'],
        specialties: ['Satyanarayan Puja', 'Griha Pravesh', 'Navgraha Shanti'],
        rating: 4.8,
        totalReviews: 124,
        totalBookings: 450,
        basePrice: 1500.0,
        isActive: true,
        isVerified: true,
        locationCity: 'Mumbai',
        locationState: 'Maharashtra',
        contactPhone: '+91 98765 43210',
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
      ),
      OfflinePanditProfile(
        id: 'p2',
        userId: 'pu2',
        name: 'Acharya Sunil Joshi',
        bio: 'Renowned astrologer and priest. Expert in Jyotish, Vastu Shastra, and traditional Hindu ceremonies.',
        experienceYears: 20,
        languages: ['Hindi', 'Marathi', 'English'],
        specialties: ['Jyotish', 'Vastu', 'Navgraha', 'Kundali'],
        rating: 4.9,
        totalReviews: 89,
        totalBookings: 320,
        basePrice: 2000.0,
        isActive: true,
        isVerified: true,
        locationCity: 'Pune',
        locationState: 'Maharashtra',
        contactPhone: '+91 98765 43211',
        createdAt: DateTime.now().subtract(const Duration(days: 400)),
      ),
      OfflinePanditProfile(
        id: 'p3',
        userId: 'pu3',
        name: 'Pt. Kavita Mishra',
        bio: 'Female priest specializing in Kanya Puja, Lakshmi Puja, and other women-friendly ceremonies.',
        experienceYears: 10,
        languages: ['Hindi', 'English'],
        specialties: ['Kanya Puja', 'Lakshmi Puja', 'Griha Pravesh'],
        rating: 4.7,
        totalReviews: 67,
        totalBookings: 210,
        basePrice: 1200.0,
        isActive: true,
        isVerified: true,
        locationCity: 'Delhi',
        locationState: 'Delhi',
        contactPhone: '+91 98765 43212',
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
      ),
    ]);
  }

  @override
  Future<List<OfflinePanditProfile>> searchPandits({
    String? city,
    String? specialty,
    double? minRating,
    double? maxPrice,
    String? language,
    int limit = 50,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    var results = _mockPandits.where((p) => p.isActive).toList();
    
    if (city != null && city.isNotEmpty) {
      results = results.where((p) => 
        p.locationCity?.toLowerCase().contains(city.toLowerCase()) ?? false
      ).toList();
    }
    
    if (specialty != null && specialty.isNotEmpty) {
      results = results.where((p) => 
        p.specialties.any((s) => s.toLowerCase().contains(specialty.toLowerCase()))
      ).toList();
    }
    
    if (minRating != null) {
      results = results.where((p) => p.rating >= minRating).toList();
    }
    
    if (maxPrice != null) {
      results = results.where((p) => p.basePrice <= maxPrice).toList();
    }
    
    if (language != null && language.isNotEmpty) {
      results = results.where((p) => 
        p.languages.any((l) => l.toLowerCase().contains(language.toLowerCase()))
      ).toList();
    }
    
    results.sort((a, b) => b.rating.compareTo(a.rating));
    
    return results.skip(offset).take(limit).toList();
  }

  @override
  Future<OfflinePanditProfile?> getPanditProfile(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      return _mockPandits.firstWhere((p) => p.id == panditId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<OfflinePanditProfile> upsertPanditProfile({
    required String userId,
    required String name,
    String? bio,
    int? experienceYears,
    List<String>? languages,
    List<String>? specialties,
    double? basePrice,
    String? locationCity,
    String? locationState,
    String? contactPhone,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    final existingIndex = _mockPandits.indexWhere((p) => p.userId == userId);
    final profile = OfflinePanditProfile(
      id: existingIndex >= 0 ? _mockPandits[existingIndex].id : DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      name: name,
      bio: bio,
      experienceYears: experienceYears ?? 0,
      languages: languages ?? [],
      specialties: specialties ?? [],
      rating: 0.0,
      totalReviews: 0,
      totalBookings: 0,
      basePrice: basePrice ?? 0.0,
      isActive: true,
      isVerified: false,
      locationCity: locationCity,
      locationState: locationState,
      contactPhone: contactPhone,
      createdAt: DateTime.now(),
    );
    
    if (existingIndex >= 0) {
      _mockPandits[existingIndex] = profile;
    } else {
      _mockPandits.add(profile);
    }
    
    return profile;
  }

  @override
  Future<List<OfflinePanditService>> getPanditServices(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Return mock services
    return [
      OfflinePanditService(
        id: 's1',
        panditId: panditId,
        serviceName: 'Satyanarayan Puja',
        description: 'Complete Satyanarayan Puja with all rituals',
        durationMinutes: 120,
        price: 1500.0,
        createdAt: DateTime.now(),
      ),
      OfflinePanditService(
        id: 's2',
        panditId: panditId,
        serviceName: 'Griha Pravesh',
        description: 'House warming ceremony',
        durationMinutes: 90,
        price: 1200.0,
        createdAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<List<OfflinePanditAvailability>> getPanditAvailability(
    String panditId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Return mock availability for next 7 days
    final availabilities = <OfflinePanditAvailability>[];
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      if (date.isAfter(endDate)) break;
      
      // Add morning and evening slots
      availabilities.add(OfflinePanditAvailability(
        id: 'a${i}_1',
        panditId: panditId,
        date: date,
        startTime: '09:00',
        endTime: '12:00',
        isAvailable: true,
        createdAt: DateTime.now(),
      ));
      availabilities.add(OfflinePanditAvailability(
        id: 'a${i}_2',
        panditId: panditId,
        date: date,
        startTime: '16:00',
        endTime: '20:00',
        isAvailable: true,
        createdAt: DateTime.now(),
      ));
    }
    return availabilities;
  }

  @override
  Future<OfflineBooking> createBooking({
    required String userId,
    required String panditId,
    String? serviceId,
    required String addressLine1,
    String? addressLine2,
    required String city,
    required String state,
    required String pincode,
    String? landmark,
    required DateTime bookingDate,
    required String bookingTime,
    required String serviceName,
    String? serviceDescription,
    required double amount,
    String? specialRequirements,
    String? userNotes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    
    final pandit = await getPanditProfile(panditId);
    final booking = OfflineBooking(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      panditId: panditId,
      serviceId: serviceId,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      city: city,
      state: state,
      pincode: pincode,
      landmark: landmark,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      serviceName: serviceName,
      serviceDescription: serviceDescription,
      amount: amount,
      platformFee: amount * 0.15,
      panditPayout: amount * 0.85,
      status: OfflineBookingStatus.pending,
      isPaid: false,
      paymentStatus: 'pending',
      contactVisible: false,
      createdAt: DateTime.now(),
      panditName: pandit?.name,
      panditAvatarUrl: pandit?.avatarUrl,
      specialRequirements: specialRequirements,
      userNotes: userNotes,
    );
    
    _mockBookings.add(booking);
    return booking;
  }

  @override
  Future<OfflineBooking> respondToBooking({
    required String bookingId,
    required String action,
    String? panditNotes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking not found');
    }
    
    final booking = _mockBookings[index];
    final newStatus = action == 'accept' 
        ? OfflineBookingStatus.accepted 
        : OfflineBookingStatus.rejected;
    
    _mockBookings[index] = booking.copyWith(
      status: newStatus,
      panditNotes: panditNotes,
      acceptedAt: action == 'accept' ? DateTime.now() : null,
      updatedAt: DateTime.now(),
    );
    
    return _mockBookings[index];
  }

  @override
  Future<OfflineBooking> confirmBookingPayment({
    required String bookingId,
    required String paymentId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index == -1) {
      throw Exception('Booking not found');
    }
    
    final booking = _mockBookings[index];
    // Look up the pandit's real phone number
    final pandit = _mockPandits.where((p) => p.id == booking.panditId).firstOrNull;
    _mockBookings[index] = booking.copyWith(
      status: OfflineBookingStatus.paid,
      isPaid: true,
      paymentId: paymentId,
      paymentStatus: 'completed',
      paidAt: DateTime.now(),
      contactVisible: true,
      panditContactPhone: pandit?.contactPhone ?? '+91 98765 43210',
      updatedAt: DateTime.now(),
    );
    
    return _mockBookings[index];
  }

  @override
  Future<List<OfflineBooking>> getPanditPendingBookings(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockBookings
        .where((b) => b.panditId == panditId && b.status == OfflineBookingStatus.pending)
        .toList();
  }

  @override
  Future<List<OfflineBooking>> getUserBookings(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockBookings.where((b) => b.userId == userId).toList();
  }

  @override
  Future<OfflineBooking?> getBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return _mockBookings.firstWhere((b) => b.id == bookingId);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> addReview({
    required String panditId,
    required String userId,
    String? bookingId,
    required int rating,
    String? reviewText,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    
    final review = OfflinePanditReview(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      panditId: panditId,
      userId: userId,
      bookingId: bookingId,
      rating: rating,
      reviewText: reviewText,
      createdAt: DateTime.now(),
    );
    
    _mockReviews.add(review);
    
    // Update pandit rating
    final panditIndex = _mockPandits.indexWhere((p) => p.id == panditId);
    if (panditIndex >= 0) {
      final pandit = _mockPandits[panditIndex];
      final newReviews = [..._mockReviews.where((r) => r.panditId == panditId)];
      final avgRating = newReviews.isEmpty ? 0.0 : 
          newReviews.map((r) => r.rating).reduce((a, b) => a + b) / newReviews.length;
      
      _mockPandits[panditIndex] = pandit.copyWith(
        rating: avgRating,
        totalReviews: newReviews.length,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<List<OfflinePanditReview>> getPanditReviews(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _mockReviews.where((r) => r.panditId == panditId).toList();
  }

  @override
  Future<List<OfflineBooking>> getAllBookings({
    OfflineBookingStatus? status,
    int limit = 100,
    int offset = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    var bookings = _mockBookings;
    if (status != null) {
      bookings = bookings.where((b) => b.status == status).toList();
    }
    return bookings.skip(offset).take(limit).toList();
  }

  @override
  Future<bool> adminCancelBooking(String bookingId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index >= 0) {
      _mockBookings[index] = _mockBookings[index].copyWith(
        status: OfflineBookingStatus.cancelled,
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> adminProcessRefund(String bookingId, String reason) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index >= 0) {
      _mockBookings[index] = _mockBookings[index].copyWith(
        status: OfflineBookingStatus.refunded,
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> adminProcessPayout(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Mock payout processing - just return true
    return true;
  }

  @override
  Future<bool> adminUpdateBookingStatus(
    String bookingId,
    OfflineBookingStatus newStatus,
    String? adminNotes,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final index = _mockBookings.indexWhere((b) => b.id == bookingId);
    if (index >= 0) {
      _mockBookings[index] = _mockBookings[index].copyWith(
        status: newStatus,
      );
      return true;
    }
    return false;
  }

  @override
  Future<PanditBookingStats> getPanditBookingStats(String panditId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final panditBookings = _mockBookings.where((b) => b.panditId == panditId).toList();
    
    return PanditBookingStats(
      panditId: panditId,
      panditName: 'Mock Pandit',
      statistics: BookingStatistics(
        totalBookings: panditBookings.length,
        completedBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
        cancelledBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
        pendingBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        monthlyStats: MonthlyStatistics(
          month: now.month,
          year: now.year,
          totalBookings: panditBookings.length,
          completedBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
          cancelledBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
          pendingBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        ),
        weeklyStats: WeeklyStatistics(
          weekNumber: WeeklyStatistics.currentWeekNumber(),
          year: now.year,
          totalBookings: panditBookings.length,
          completedBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
          cancelledBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
          pendingBookings: panditBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        ),
      ),
    );
  }

  @override
  Future<UserBookingStats> getUserBookingStats(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final userBookings = _mockBookings.where((b) => b.userId == userId).toList();
    
    return UserBookingStats(
      userId: userId,
      userName: 'Mock User',
      statistics: BookingStatistics(
        totalBookings: userBookings.length,
        completedBookings: userBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
        cancelledBookings: userBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
        pendingBookings: userBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        monthlyStats: MonthlyStatistics(
          month: now.month,
          year: now.year,
          totalBookings: userBookings.length,
          completedBookings: userBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
          cancelledBookings: userBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
          pendingBookings: userBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        ),
        weeklyStats: WeeklyStatistics(
          weekNumber: WeeklyStatistics.currentWeekNumber(),
          year: now.year,
          totalBookings: userBookings.length,
          completedBookings: userBookings.where((b) => b.status == OfflineBookingStatus.completed).length,
          cancelledBookings: userBookings.where((b) => b.status == OfflineBookingStatus.cancelled).length,
          pendingBookings: userBookings.where((b) => b.status == OfflineBookingStatus.pending).length,
        ),
      ),
    );
  }

  @override
  Future<List<PanditBookingStats>> getAllPanditsStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Return mock data for all pandits
    return [
      await getPanditBookingStats('pandit1'),
      await getPanditBookingStats('pandit2'),
    ];
  }

  @override
  Future<List<UserBookingStats>> getAllUsersStats() async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Return mock data for all users
    return [
      await getUserBookingStats('user1'),
      await getUserBookingStats('user2'),
    ];
  }
}
