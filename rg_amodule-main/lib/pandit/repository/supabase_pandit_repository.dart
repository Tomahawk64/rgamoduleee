// lib/pandit/repository/supabase_pandit_repository.dart
//
// Production Supabase implementation of [IPanditDashboardRepository].
// Matches the DB schema in supabase/migrations/.

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../booking/models/booking_model.dart';
import '../../booking/models/booking_status.dart';
import '../../booking/models/time_slot_model.dart';
import '../models/pandit_dashboard_models.dart';
import 'pandit_repository.dart';

class SupabasePanditDashboardRepository
    implements IPanditDashboardRepository {
  SupabasePanditDashboardRepository()
      : _db = Supabase.instance.client;

  final SupabaseClient _db;

  // ── Fetch assignments ────────────────────────────────────────────────────

  @override
  Future<List<PanditAssignment>> fetchAssignments(String panditId) async {
    final rows = await _db
        .from('bookings')
        .select('*')
        .eq('pandit_id', panditId)
        .order('booking_date', ascending: true);

    return (rows as List<dynamic>)
        .map((r) => _rowToAssignment(r as Map<String, dynamic>))
        .toList();
  }

  // ── Update status ────────────────────────────────────────────────────────

  @override
  Future<void> updateStatus(String bookingId, BookingStatus newStatus) async {
    await _db
        .from('bookings')
        .update({'status': newStatus.name})
        .eq('id', bookingId);
  }

  // ── Fetch profile ────────────────────────────────────────────────────────

  @override
  Future<PanditProfile> fetchProfile(String panditId) async {
    // profiles holds name/rating; pandit_details holds specialties/bio/etc.
    final results = await Future.wait([
      _db.from('profiles').select('id, full_name, rating, avatar_url').eq('id', panditId).maybeSingle(),
      _db.from('pandit_details').select().eq('id', panditId).maybeSingle(),
    ]);

    final profileRow = results[0];
    final detailsRow = results[1];

    if (profileRow == null && detailsRow == null) {
      return PanditProfile(
        id: panditId,
        name: 'Pandit',
        specialties: const [],
        rating: 0.0,
        totalBookings: 0,
        consultationEnabled: false,
        offlineBookingEnabled: false,
        yearsExperience: 0,
        languages: const ['Hindi'],
      );
    }

    final specialties = (detailsRow?['specialties'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        [];
    final languages = (detailsRow?['languages'] as List<dynamic>?)
            ?.map((s) => s.toString())
            .toList() ??
        ['Hindi'];

    return PanditProfile(
      id: panditId,
      name: profileRow?['full_name'] as String? ?? 'Pandit',
      specialties: specialties,
      rating: (profileRow?['rating'] as num?)?.toDouble() ?? 0.0,
      totalBookings: 0,
      consultationEnabled: detailsRow?['consultation_enabled'] as bool? ?? false,
      offlineBookingEnabled: detailsRow?['offline_booking_enabled'] as bool? ?? false,
      yearsExperience: (detailsRow?['experience_years'] as num?)?.toInt() ?? 0,
      languages: languages,
      bio: detailsRow?['bio'] as String?,
      avatarUrl: profileRow?['avatar_url'] as String?,
      isOnline: detailsRow?['is_online'] as bool? ?? false,
    );
  }

  // ── Toggle consultation ──────────────────────────────────────────────────

  @override
  Future<void> setConsultationEnabled(
    String panditId, {
    required bool enabled,
  }) async {
    // Use a SECURITY DEFINER RPC so the upsert always succeeds regardless
    // of whether the pandit_details row already exists, and RLS is bypassed.
    await _db.rpc('pandit_set_consultation_enabled', params: {
      'p_enabled': enabled,
    });
  }
  // Toggle online status ───────────────────────────────────────────────────

  @override
  Future<void> setOnlineStatus(
    String panditId, {
    required bool isOnline,
  }) async {
    await _db
        .from('pandit_details')
        .update({'is_online': isOnline})
        .eq('id', panditId);
  }

  @override
  Future<void> setOfflineBookingEnabled(
    String panditId, {
    required bool enabled,
  }) async {
    await _db
        .from('pandit_details')
        .update({'offline_booking_enabled': enabled})
        .eq('id', panditId);
  }

  // ── Update avatar URL ────────────────────────────────────────────────────

  @override
  Future<void> updateAvatarUrl(String panditId, String url) async {
    await _db
        .from('profiles')
        .update({'avatar_url': url})
        .eq('id', panditId);
  }

  // ── Fetch earnings ───────────────────────────────────────────────────────

  @override
  Future<EarningsSummary> fetchEarnings(String panditId) async {
    final now = DateTime.now();

    final rows = await _db
        .from('bookings')
        .select('amount, booking_date, status')
        .eq('pandit_id', panditId)
        .eq('status', 'completed');

    final all = rows as List<dynamic>;
    int totalPaise = 0;
    int monthPaise = 0;
    int totalCount = 0;
    int monthCount = 0;

    for (final r in all) {
      final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
      final paise = (amount * 100).round();
      totalPaise += paise;
      totalCount++;

      final date = DateTime.tryParse(r['booking_date'] as String? ?? '');
      if (date != null &&
          date.year == now.year &&
          date.month == now.month) {
        monthPaise += paise;
        monthCount++;
      }
    }

    // 20% platform fee retained — pandit earns 80%
    return EarningsSummary(
      totalEarnedPaise: (totalPaise * 0.80).round(),
      thisMonthPaise: (monthPaise * 0.80).round(),
      pendingPayoutPaise: (totalPaise * 0.20).round(),
      completedCount: totalCount,
      thisMonthCount: monthCount,
    );
  }

  PanditAssignment _rowToAssignment(Map<String, dynamic> r) {
    dynamic slotData = r['slot'];
    dynamic locData = r['location'];

    // Supabase may return jsonb as Map or String
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return {};
    }

    return PanditAssignment(
      panditAccepted: r['pandit_accepted'] as bool? ?? false,
      booking: BookingModel(
        id: r['id'] as String,
        userId: r['user_id'] as String? ?? '',
        packageId: r['package_id'] as String? ?? '',
        packageTitle: r['package_title'] as String? ?? 'Pooja',
        category: r['category'] as String? ?? '',
        date: DateTime.tryParse(r['booking_date'] as String? ?? '') ??
            DateTime.now(),
        slot: slotData != null
            ? TimeSlot.fromJson(asMap(slotData))
            : const TimeSlot(
                id: '',
                startHour: 9,
                startMinute: 0,
                endHour: 11,
                endMinute: 0),
        location: locData != null
            ? BookingLocation.fromJson(asMap(locData))
            : const BookingLocation(),
        status: BookingStatus.values.firstWhere(
          (s) => s.name == (r['status'] as String? ?? 'pending'),
          orElse: () => BookingStatus.pending,
        ),
        amount: (r['amount'] as num?)?.toDouble() ?? 0.0,
        createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ??
            DateTime.now(),
        panditId: r['pandit_id'] as String?,
        panditName: r['pandit_name'] as String?,
        isPaid: r['is_paid'] as bool? ?? false,
        paymentId: r['payment_id'] as String?,
        notes: r['notes'] as String?,
        isAutoAssigned: r['is_auto_assigned'] as bool? ?? false,
      ),
    );
  }
}
