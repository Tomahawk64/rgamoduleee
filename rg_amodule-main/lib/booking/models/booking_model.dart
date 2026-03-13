import 'dart:convert';

import 'booking_status.dart';
import 'time_slot_model.dart';

// ── Location ──────────────────────────────────────────────────────────────────
class BookingLocation {
  const BookingLocation({
    this.isOnline = false,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.pincode,
    this.meetLink,
  });

  final bool isOnline;
  // Offline fields
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? pincode;
  // Online field (set by admin/pandit after confirmation)
  final String? meetLink;

  String get displayAddress {
    if (isOnline) return meetLink != null ? 'Online: $meetLink' : 'Online';
    final parts = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
      city,
      pincode,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'is_online':      isOnline,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'city':           city,
        'pincode':        pincode,
        'meet_link':      meetLink,
      };

  factory BookingLocation.fromJson(Map<String, dynamic> j) => BookingLocation(
        isOnline:     j['is_online'] as bool? ?? false,
        addressLine1: j['address_line_1'] as String?,
        addressLine2: j['address_line_2'] as String?,
        city:         j['city'] as String?,
        pincode:      j['pincode'] as String?,
        meetLink:     j['meet_link'] as String?,
      );
}

// ── Pandit Option ─────────────────────────────────────────────────────────────
class PanditOption {
  const PanditOption({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.totalBookings,
    this.imageUrl,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int totalBookings;
  final String? imageUrl;
  final bool isAvailable;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}

/// Sentinel value for auto-assign.
const kAutoAssignPandit = PanditOption(
  id: 'auto',
  name: 'Auto Assign',
  specialty: 'Best available pandit will be assigned',
  rating: 0,
  totalBookings: 0,
);

/// Mock pandit catalogue (replace with Supabase query).
const kMockPandits = [
  kAutoAssignPandit,
  PanditOption(
    id: 'p001',
    name: 'Pt. Ramesh Sharma',
    specialty: 'Vaishnavism · Griha Pravesh · Satyanarayan',
    rating: 4.9,
    totalBookings: 1240,
  ),
  PanditOption(
    id: 'p002',
    name: 'Acharya Sunil Joshi',
    specialty: 'Jyotish · Vastu · Navgraha',
    rating: 4.7,
    totalBookings: 870,
  ),
  PanditOption(
    id: 'p003',
    name: 'Pt. Kavita Mishra',
    specialty: 'Griha Pravesh · Havan · Kanya Puja',
    rating: 4.8,
    totalBookings: 650,
  ),
  PanditOption(
    id: 'p004',
    name: 'Pt. Ashok Trivedi',
    specialty: 'Sunderkand · Katha · Aarti',
    rating: 4.8,
    totalBookings: 1850,
  ),
  PanditOption(
    id: 'p005',
    name: 'Swami Prakash Das',
    specialty: 'Havan · Navgraha · Mangal shanti',
    rating: 5.0,
    totalBookings: 310,
  ),
];

// ── Booking Model ─────────────────────────────────────────────────────────────
class BookingModel {
  const BookingModel({
    required this.id,
    required this.userId,
    required this.packageId,
    required this.packageTitle,
    required this.category,
    required this.date,
    required this.slot,
    required this.location,
    required this.status,
    required this.amount,
    required this.createdAt,
    this.panditId,
    this.panditName,
    this.isPaid = false,
    this.paymentId,
    this.notes,
    this.isAutoAssigned = false,
  });

  final String id;
  final String userId;
  final String packageId;
  final String packageTitle;
  final String category;
  final DateTime date;
  final TimeSlot slot;
  final BookingLocation location;
  final BookingStatus status;
  final double amount;
  final DateTime createdAt;
  final String? panditId;
  final String? panditName;
  final bool isPaid;
  final String? paymentId;
  final String? notes;
  final bool isAutoAssigned;

  /// Composite key used to detect duplicate slot bookings.
  String get slotKey => '${_dateStr(date)}_${slot.id}';

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool get isUpcoming =>
      status.isActive && date.isAfter(DateTime.now().subtract(const Duration(hours: 1)));

  bool get isPast => status.isFinal || date.isBefore(DateTime.now());

  // ── Serialisation (Supabase-ready) ────────────────────────────────────────
  // NOTE: pandit_name is intentionally excluded — it is NOT a column in the
  // bookings table. The name is resolved at read time via a profiles JOIN.
  Map<String, dynamic> toJson() => {
        'id':            id,
        'user_id':       userId,
        'package_id':    packageId,
        'package_title': packageTitle,
        'category':      category,
        'booking_date':   date.toIso8601String(),
        'slot':          slot.toJson(),
        'location':      location.toJson(),
        'status':        status.dbValue,
        'amount':        amount,
        'created_at':    createdAt.toIso8601String(),
        'pandit_id':     panditId,
        'is_paid':       isPaid,
        'payment_id':    paymentId,
        'notes':         notes,
        'is_auto_assigned': isAutoAssigned,
      };

  /// Safely decodes a jsonb field that Supabase may return as either a
  /// [Map<String, dynamic>] or an already-serialised JSON [String].
  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String) return jsonDecode(v) as Map<String, dynamic>;
    throw FormatException('Cannot decode jsonb field: $v');
  }

  factory BookingModel.fromJson(Map<String, dynamic> j) => BookingModel(
        id:            j['id'] as String,
        userId:        j['user_id'] as String,
        packageId:     j['package_id'] as String,
        packageTitle:  j['package_title'] as String,
        category:      j['category'] as String? ?? '',
        date:          DateTime.parse(j['booking_date'] as String),
        slot:          TimeSlot.fromJson(_asMap(j['slot'])),
        location:      BookingLocation.fromJson(_asMap(j['location'])),
        status:        BookingStatusX.fromDb(j['status'] as String? ?? 'pending'),
        amount:        (j['amount'] as num).toDouble(),
        createdAt:     DateTime.parse(j['created_at'] as String),
        panditId:      j['pandit_id'] as String?,
        panditName:    j['pandit_name'] as String?,
        isPaid:        j['is_paid'] as bool? ?? false,
        paymentId:     j['payment_id'] as String?,
        notes:         j['notes'] as String?,
        isAutoAssigned: j['is_auto_assigned'] as bool? ?? false,
      );

  BookingModel copyWith({BookingStatus? status, String? panditId, String? panditName, bool? isPaid, String? paymentId}) =>
      BookingModel(
        id:             id,
        userId:         userId,
        packageId:      packageId,
        packageTitle:   packageTitle,
        category:       category,
        date:           date,
        slot:           slot,
        location:       location,
        status:         status ?? this.status,
        amount:         amount,
        createdAt:      createdAt,
        panditId:       panditId ?? this.panditId,
        panditName:     panditName ?? this.panditName,
        isPaid:         isPaid ?? this.isPaid,
        paymentId:      paymentId ?? this.paymentId,
        notes:          notes,
        isAutoAssigned: isAutoAssigned,
      );
}
