// lib/booking/repository/booking_repository.dart
//
// ── Database table: bookings ──────────────────────────────────────────────────
//   id                text        primary key  (uuid v4)
//   user_id           uuid        not null  references auth.users(id) on delete cascade
//   package_id        text        not null
//   package_title     text        not null
//   category          text        not null default ''
//   booking_date      date        not null
//   slot_id           text        not null  (denorm'd for the unique index)
//   slot              jsonb       not null
//   location          jsonb       not null
//   status            text        not null default 'pending'
//                                  check (status in ('pending','confirmed','assigned','completed','cancelled'))
//   amount            numeric     not null
//   created_at        timestamptz not null default now()
//   pandit_id         uuid        references profiles(id)
//   pandit_name       text        (NOT a DB column — resolved via profiles JOIN)
//   is_paid           bool        not null default false
//   payment_id        text
//   notes             text
//   is_auto_assigned  bool        not null default false
//
// ── Slot-uniqueness constraint ────────────────────────────────────────────────
//   create unique index bookings_slot_unique_idx
//     on bookings(package_id, booking_date, slot_id)
//     where status != 'cancelled';
//
//   PostgrestException.code == '23505' on violation → SlotConflictException.
//
// ── RLS policies ─────────────────────────────────────────────────────────────
//   Users   : select / insert / update  where auth.uid() = user_id
//   Pandits : select / update           where pandit_id = auth.uid()::text
//   This repository NEVER bypasses RLS.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../packages/models/package_model.dart';
import '../models/booking_draft.dart';
import '../models/booking_model.dart';
import '../models/booking_status.dart';
import '../models/time_slot_model.dart';

// ── Pagination default ────────────────────────────────────────────────────────

/// Default page size for paginated list queries.
const kDefaultPageSize = 20;

// ── Exceptions ────────────────────────────────────────────────────────────────

/// Generic booking data-access error.
class BookingException implements Exception {
  const BookingException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thrown when the unique index on (package_id, booking_date, slot_id) is violated.
class SlotConflictException extends BookingException {
  const SlotConflictException()
      : super(
            'This time slot was just taken. Please choose another time.');
}

// ── Abstract interface ────────────────────────────────────────────────────────

abstract class IBookingRepository {
  /// Bookings for [userId], newest first. Paginated via [page] (0-based).
  Future<List<BookingModel>> getBookingsForUser(
    String userId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  });

  /// Bookings assigned to [panditId], newest first. Paginated via [page].
  Future<List<BookingModel>> getBookingsForPandit(
    String panditId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  });

  /// Slot IDs already taken for [date] + [packageId] (non-cancelled).
  Future<Set<String>> getBookedSlotIds(DateTime date, String packageId);

  /// Creates a booking from [draft] for [userId].
  /// Throws [SlotConflictException] on unique constraint violation.
  Future<BookingModel> createBooking({
    required BookingDraft draft,
    required String userId,
  });

  /// Cancels a booking. Throws [BookingException] if already final.
  Future<BookingModel> cancelBooking(String bookingId);

  /// Updates the status of any booking (admin / pandit path).
  Future<BookingModel> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  );
}

// ── SupabaseBookingRepository ─────────────────────────────────────────────────

/// Production implementation backed by Supabase PostgREST.
/// All queries respect the table's Row Level Security policies.
class SupabaseBookingRepository implements IBookingRepository {
  SupabaseBookingRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BookingModel>> getBookingsForUser(
    String userId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  }) async {
    try {
      final offset = page * pageSize;
      final rows = await _client
          .from('bookings')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      return rows.map(_rowToModel).toList();
    } on PostgrestException catch (e) {
      throw BookingException('Failed to load bookings: ${e.message}');
    }
  }

  @override
  Future<List<BookingModel>> getBookingsForPandit(
    String panditId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  }) async {
    try {
      final offset = page * pageSize;
      final rows = await _client
          .from('bookings')
          .select('*')
          .eq('pandit_id', panditId)
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      return rows.map(_rowToModel).toList();
    } on PostgrestException catch (e) {
      throw BookingException(
          'Failed to load pandit bookings: ${e.message}');
    }
  }

  @override
  Future<Set<String>> getBookedSlotIds(
    DateTime date,
    String packageId,
  ) async {
    try {
      final rows = await _client
          .from('bookings')
          .select('slot_id')
          .eq('package_id', packageId)
          .eq('booking_date', _fmtDate(date))
          .neq('status', BookingStatus.cancelled.dbValue);
      return {for (final r in rows) r['slot_id'] as String};
    } on PostgrestException catch (e) {
      throw BookingException(
          'Failed to fetch slot availability: ${e.message}');
    }
  }

  @override
  Future<BookingModel> createBooking({
    required BookingDraft draft,
    required String userId,
  }) async {
    if (!draft.readyToConfirm) {
      throw const BookingException('Incomplete booking draft.');
    }

    final pkg    = draft.package!;
    final slot   = draft.slot!;
    final date   = draft.date!;
    final pandit = draft.isAutoAssign ? null : draft.panditOption;
    final packageUuid = _toUuidOrNull(pkg.id);

    if (packageUuid == null) {
      throw const BookingException(
        'Selected package is not synced with backend. Please choose a package from the latest list.',
      );
    }

    try {
      // Use the create_booking RPC which holds an advisory lock on the slot,
      // preventing race conditions that a direct INSERT cannot guard against.
      final result = await _client.rpc('create_booking', params: {
        'p_package_id':       packageUuid,
        'p_special_pooja_id': null,
        'p_package_title':    pkg.title,
        'p_category':         pkg.category.label,
        'p_booking_date':     _fmtDate(date),
        'p_slot_id':          slot.id,
        'p_slot':             slot.toJson(),
        'p_location':
            (draft.location ?? const BookingLocation(isOnline: true))
                .toJson(),
        'p_pandit_id': _toUuidOrNull(pandit?.id),
        'p_amount':    pkg.effectivePrice,
        'p_notes':     draft.notes,
        'p_is_auto_assign': draft.isAutoAssign,
      });

      final data = result as Map<String, dynamic>;

      if (data['error'] != null) {
        if (data['code'] == 'SLOT_CONFLICT') {
          throw const SlotConflictException();
        }
        throw BookingException(data['error'] as String);
      }

      // Fetch the full row (with pandit profile join) for the domain model.
      final bookingId = data['booking_id'] as String;
      final fetched = await _client
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();
      return _rowToModel(fetched);
    } on SlotConflictException {
      rethrow;
    } on BookingException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw const SlotConflictException();
      throw BookingException('Failed to create booking: ${e.message}');
    }
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    return _rpcUpdateStatus(bookingId, BookingStatus.cancelled);
  }

  @override
  Future<BookingModel> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    return _rpcUpdateStatus(bookingId, status);
  }

  /// Calls the server-authoritative [update_booking_status] RPC which
  /// enforces role-based state machine transitions.
  Future<BookingModel> _rpcUpdateStatus(
      String bookingId, BookingStatus newStatus) async {
    try {
      final result = await _client.rpc('update_booking_status', params: {
        'p_booking_id': bookingId,
        'p_new_status': newStatus.dbValue,
      });

      final data = result as Map<String, dynamic>;
      if (data['error'] != null) {
        throw BookingException(data['error'] as String);
      }

        // Fetch updated row so caller gets full BookingModel.
      final fetched = await _client
          .from('bookings')
          .select('*')
          .eq('id', bookingId)
          .single();
      return _rowToModel(fetched);
    } on BookingException {
      rethrow;
    } on PostgrestException catch (e) {
      throw BookingException(
          'Failed to update booking status: ${e.message}');
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Maps a raw Supabase row to [BookingModel].
  /// If a joined [pandit] key exists, it is flattened into [pandit_name].
  static BookingModel _rowToModel(Map<String, dynamic> row) {
    try {
      // Extract pandit name from the joined profiles row (if present).
      final panditJoin = row['pandit'] as Map<String, dynamic>?;
      final panditName = panditJoin?['full_name'] as String?;
      // Build a clean row without the nested join object so fromJson
      // doesn't trip over the unexpected key.
      final cleanRow = Map<String, dynamic>.from(row)
        ..remove('pandit')
        ..['pandit_name'] = panditName;
      return BookingModel.fromJson(cleanRow);
    } catch (e, st) {
      // Silently rethrow — no console output in production.
      assert(() {
        // Only log in debug mode.
        // ignore: avoid_print
        print('⛔ _rowToModel failed: $e\nRow: $row\n$st');
        return true;
      }());
      rethrow;
    }
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Returns [id] only when it is a well-formed UUID v4; otherwise null.
  /// Prevents short mock IDs (e.g. "p001") from reaching a uuid-typed column.
  static String? _toUuidOrNull(String? id) {
    if (id == null) return null;
    const uuidPattern =
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    return RegExp(uuidPattern, caseSensitive: false).hasMatch(id) ? id : null;
  }
}

// ── MockBookingRepository ─────────────────────────────────────────────────────

/// In-memory mock for offline development and unit tests.
/// Pre-seeded with 3 demo bookings for `userId = 'mock_user'`.
class MockBookingRepository implements IBookingRepository {
  MockBookingRepository();

  final List<BookingModel> _store = List.from(_seedBookings);

  /// Key format: `"YYYY-MM-DD_slotId"` → set of packageIds booked there.
  final Map<String, Set<String>> _bookedSlotKeys = {
    '${_todayStr()}_slot_1000': {'pkg001'},
    '${_tomorrowStr()}_slot_0800': {'pkg001', 'pkg003'},
    '${_tomorrowStr()}_slot_0700': {'pkg002'},
  };

  @override
  Future<List<BookingModel>> getBookingsForUser(
    String userId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  }) async {
    await _delay();
    final all = _store
        .where((b) => b.userId == userId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final offset = page * pageSize;
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + pageSize).clamp(0, all.length));
  }

  @override
  Future<List<BookingModel>> getBookingsForPandit(
    String panditId, {
    int page = 0,
    int pageSize = kDefaultPageSize,
  }) async {
    await _delay();
    final all = _store
        .where((b) => b.panditId == panditId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final offset = page * pageSize;
    if (offset >= all.length) return [];
    return all.sublist(offset, (offset + pageSize).clamp(0, all.length));
  }

  @override
  Future<Set<String>> getBookedSlotIds(
    DateTime date,
    String packageId,
  ) async {
    await _delay(ms: 300);
    final prefix = '${_fmtDate(date)}_';
    final result = <String>{};
    for (final entry in _bookedSlotKeys.entries) {
      if (entry.key.startsWith(prefix) && entry.value.contains(packageId)) {
        result.add(entry.key.substring(entry.key.indexOf('_') + 1));
      }
    }
    return result;
  }

  @override
  Future<BookingModel> createBooking({
    required BookingDraft draft,
    required String userId,
  }) async {
    if (!draft.readyToConfirm) {
      throw const BookingException('Incomplete booking draft.');
    }
    await _delay(ms: 600);

    final pkg    = draft.package!;
    final slot   = draft.slot!;
    final date   = draft.date!;
    final pandit = draft.isAutoAssign ? null : draft.panditOption;

    // Mirrors the partial unique index check.
    final takenIds = await getBookedSlotIds(date, pkg.id);
    if (takenIds.contains(slot.id)) throw const SlotConflictException();

    final booking = BookingModel(
      id:             _generateId(),
      userId:         userId,
      packageId:      pkg.id,
      packageTitle:   pkg.title,
      category:       pkg.category.label,
      date:           date,
      slot:           slot,
      location:       draft.location ?? const BookingLocation(isOnline: true),
      status:         BookingStatus.pending,
      amount:         pkg.effectivePrice,
      createdAt:      DateTime.now(),
      panditId:       pandit?.id,
      panditName:     pandit?.name,
      isAutoAssigned: draft.isAutoAssign,
    );

    _store.add(booking);
    _bookedSlotKeys
        .putIfAbsent('${_fmtDate(date)}_${slot.id}', () => {})
        .add(pkg.id);
    return booking;
  }

  @override
  Future<BookingModel> cancelBooking(String bookingId) async {
    await _delay();
    final idx = _store.indexWhere((b) => b.id == bookingId);
    if (idx == -1) throw const BookingException('Booking not found.');
    if (_store[idx].status.isFinal) {
      throw const BookingException(
          'Cannot cancel a completed or already-cancelled booking.');
    }
    final updated = _store[idx].copyWith(status: BookingStatus.cancelled);
    _store[idx] = updated;
    return updated;
  }

  @override
  Future<BookingModel> updateBookingStatus(
    String bookingId,
    BookingStatus status,
  ) async {
    await _delay();
    final idx = _store.indexWhere((b) => b.id == bookingId);
    if (idx == -1) throw const BookingException('Booking not found.');
    final updated = _store[idx].copyWith(status: status);
    _store[idx] = updated;
    return updated;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static Future<void> _delay({int ms = 400}) =>
      Future.delayed(Duration(milliseconds: ms));

  static String _generateId() =>
      'bk_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _todayStr() => _fmtDate(DateTime.now());

  static String _tomorrowStr() =>
      _fmtDate(DateTime.now().add(const Duration(days: 1)));
}

// ── Seed data ─────────────────────────────────────────────────────────────────

List<BookingModel> get _seedBookings => [
      BookingModel(
        id: 'bk_seed_001',
        userId: 'mock_user',
        packageId: 'pkg001',
        packageTitle: 'Satyanarayan Puja',
        category: 'Puja',
        date: DateTime.now().add(const Duration(days: 4)),
        slot: kStandardTimeSlots[4], // 10:00–11:00
        location: const BookingLocation(
          isOnline: false,
          addressLine1: '42, Shanti Nagar',
          city: 'Jaipur',
          pincode: '302001',
        ),
        status: BookingStatus.confirmed,
        amount: 1499,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        panditName: 'Pt. Ramesh Sharma',
        panditId: 'p001',
      ),
      BookingModel(
        id: 'bk_seed_002',
        userId: 'mock_user',
        packageId: 'pkg006',
        packageTitle: 'Sunderkand Path',
        category: 'Katha',
        date: DateTime.now().add(const Duration(days: 10)),
        slot: kStandardTimeSlots[1], // 07:00–08:00
        location: const BookingLocation(isOnline: true),
        status: BookingStatus.pending,
        amount: 1199,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isAutoAssigned: true,
      ),
      BookingModel(
        id: 'bk_seed_003',
        userId: 'mock_user',
        packageId: 'pkg004',
        packageTitle: 'Navgraha Shanti Havan',
        category: 'Havan',
        date: DateTime.now().subtract(const Duration(days: 30)),
        slot: kStandardTimeSlots[2], // 08:00–09:00
        location: const BookingLocation(
          isOnline: false,
          addressLine1: '7, Ram Vihar Colony',
          city: 'Delhi',
          pincode: '110092',
        ),
        status: BookingStatus.completed,
        amount: 3499,
        createdAt: DateTime.now().subtract(const Duration(days: 35)),
        panditName: 'Swami Prakash Das',
        panditId: 'p005',
        isPaid: true,
      ),
    ];
