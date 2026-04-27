// lib/offline_booking/models/offline_booking_models.dart
// Models for the Offline Pandit Booking Marketplace

// ── Booking Status Enum ─────────────────────────────────────────────────────────────

enum OfflineBookingStatus {
  pending,
  accepted,
  rejected,
  paid,
  confirmed,
  inProgress,
  completed,
  cancelled,
  refunded,
}

extension OfflineBookingStatusX on OfflineBookingStatus {
  String get label {
    switch (this) {
      case OfflineBookingStatus.pending:
        return 'Pending Approval';
      case OfflineBookingStatus.accepted:
        return 'Accepted';
      case OfflineBookingStatus.rejected:
        return 'Rejected';
      case OfflineBookingStatus.paid:
        return 'Payment Complete';
      case OfflineBookingStatus.confirmed:
        return 'Confirmed';
      case OfflineBookingStatus.inProgress:
        return 'In Progress';
      case OfflineBookingStatus.completed:
        return 'Completed';
      case OfflineBookingStatus.cancelled:
        return 'Cancelled';
      case OfflineBookingStatus.refunded:
        return 'Refunded';
    }
  }

  String get value {
    switch (this) {
      case OfflineBookingStatus.pending:
        return 'pending';
      case OfflineBookingStatus.accepted:
        return 'accepted';
      case OfflineBookingStatus.rejected:
        return 'rejected';
      case OfflineBookingStatus.paid:
        return 'paid';
      case OfflineBookingStatus.confirmed:
        return 'confirmed';
      case OfflineBookingStatus.inProgress:
        return 'in_progress';
      case OfflineBookingStatus.completed:
        return 'completed';
      case OfflineBookingStatus.cancelled:
        return 'cancelled';
      case OfflineBookingStatus.refunded:
        return 'refunded';
    }
  }

  bool get isPending => this == OfflineBookingStatus.pending;
  bool get isAccepted => this == OfflineBookingStatus.accepted;
  bool get isRejected => this == OfflineBookingStatus.rejected;
  bool get isPaid => this == OfflineBookingStatus.paid;
  bool get isConfirmed => this == OfflineBookingStatus.confirmed;
  bool get isInProgress => this == OfflineBookingStatus.inProgress;
  bool get isCompleted => this == OfflineBookingStatus.completed;
  bool get isCancelled => this == OfflineBookingStatus.cancelled;
  bool get isRefunded => this == OfflineBookingStatus.refunded;
  
  bool get isFinal => isCompleted || isCancelled || isRefunded;
  bool get isActive => isAccepted || isPaid || isConfirmed || isInProgress;
  bool get requiresPayment => isAccepted;
}

OfflineBookingStatus bookingStatusFromDb(String status) {
  switch (status) {
    case 'pending':
      return OfflineBookingStatus.pending;
    case 'accepted':
      return OfflineBookingStatus.accepted;
    case 'rejected':
      return OfflineBookingStatus.rejected;
    case 'paid':
      return OfflineBookingStatus.paid;
    case 'confirmed':
      return OfflineBookingStatus.confirmed;
    case 'in_progress':
      return OfflineBookingStatus.inProgress;
    case 'completed':
      return OfflineBookingStatus.completed;
    case 'cancelled':
      return OfflineBookingStatus.cancelled;
    case 'refunded':
      return OfflineBookingStatus.refunded;
    default:
      return OfflineBookingStatus.pending;
  }
}

// ── Offline Pandit Service ───────────────────────────────────────────────────────────

class OfflinePanditService {
  const OfflinePanditService({
    required this.id,
    required this.panditId,
    required this.serviceName,
    this.description,
    this.durationMinutes,
    required this.price,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String panditId;
  final String serviceName;
  final String? description;
  final int? durationMinutes;
  final double price;
  final bool isActive;
  final DateTime createdAt;

  String get priceLabel => '₹${price.toStringAsFixed(0)}';
  String get durationLabel => durationMinutes != null ? '$durationMinutes min' : 'Flexible';

  factory OfflinePanditService.fromJson(Map<String, dynamic> json) {
    return OfflinePanditService(
      id: json['id'] as String,
      panditId: json['pandit_id'] as String,
      serviceName: json['service_name'] as String,
      description: json['description'] as String?,
      durationMinutes: json['duration_minutes'] as int?,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pandit_id': panditId,
        'service_name': serviceName,
        'description': description,
        'duration_minutes': durationMinutes,
        'price': price,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── Offline Pandit Review ───────────────────────────────────────────────────────────

class OfflinePanditReview {
  const OfflinePanditReview({
    required this.id,
    required this.panditId,
    required this.userId,
    this.bookingId,
    required this.rating,
    this.reviewText,
    this.isVisible = true,
    required this.createdAt,
  });

  final String id;
  final String panditId;
  final String userId;
  final String? bookingId;
  final int rating;
  final String? reviewText;
  final bool isVisible;
  final DateTime createdAt;

  factory OfflinePanditReview.fromJson(Map<String, dynamic> json) {
    return OfflinePanditReview(
      id: json['id'] as String,
      panditId: json['pandit_id'] as String,
      userId: json['user_id'] as String,
      bookingId: json['booking_id'] as String?,
      rating: json['rating'] as int,
      reviewText: json['review_text'] as String?,
      isVisible: json['is_visible'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pandit_id': panditId,
        'user_id': userId,
        'booking_id': bookingId,
        'rating': rating,
        'review_text': reviewText,
        'is_visible': isVisible,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── Offline Pandit Availability ─────────────────────────────────────────────────────

class OfflinePanditAvailability {
  const OfflinePanditAvailability({
    required this.id,
    required this.panditId,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.isAvailable = true,
    required this.createdAt,
  });

  final String id;
  final String panditId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final bool isAvailable;
  final DateTime createdAt;

  factory OfflinePanditAvailability.fromJson(Map<String, dynamic> json) {
    return OfflinePanditAvailability(
      id: json['id'] as String,
      panditId: json['pandit_id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'pandit_id': panditId,
        'date': date.toIso8601String(),
        'start_time': startTime,
        'end_time': endTime,
        'is_available': isAvailable,
        'created_at': createdAt.toIso8601String(),
      };
}

// ── Offline Pandit Profile ───────────────────────────────────────────────────────────

class OfflinePanditProfile {
  const OfflinePanditProfile({
    required this.id,
    this.userId,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.experienceYears = 0,
    this.languages = const [],
    this.specialties = const [],
    this.rating = 0.0,
    this.totalReviews = 0,
    this.totalBookings = 0,
    this.basePrice = 0.0,
    this.isActive = true,
    this.isVerified = false,
    this.locationCity,
    this.locationState,
    this.contactPhone,
    required this.createdAt,
    this.updatedAt,
    this.services = const [],
    this.reviews = const [],
  });

  final String id;
  final String? userId;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final int experienceYears;
  final List<String> languages;
  final List<String> specialties;
  final double rating;
  final int totalReviews;
  final int totalBookings;
  final double basePrice;
  final bool isActive;
  final bool isVerified;
  final String? locationCity;
  final String? locationState;
  final String? contactPhone;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<OfflinePanditService> services;
  final List<OfflinePanditReview> reviews;

  String get location {
    if (locationCity != null && locationState != null) {
      return '$locationCity, $locationState';
    }
    return locationCity ?? locationState ?? 'Location not specified';
  }

  String get experienceLabel => experienceYears > 0 ? '$experienceYears years' : 'New';
  String get ratingLabel => rating > 0 ? '$rating' : 'New';

  factory OfflinePanditProfile.fromJson(Map<String, dynamic> json) {
    return OfflinePanditProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      experienceYears: json['experience_years'] as int? ?? 0,
      languages: (json['languages'] as List?)?.cast<String>() ?? [],
      specialties: (json['specialties'] as List?)?.cast<String>() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      totalBookings: json['total_bookings'] as int? ?? 0,
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      locationCity: json['location_city'] as String?,
      locationState: json['location_state'] as String?,
      contactPhone: json['contact_phone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'avatar_url': avatarUrl,
        'bio': bio,
        'experience_years': experienceYears,
        'languages': languages,
        'specialties': specialties,
        'rating': rating,
        'total_reviews': totalReviews,
        'total_bookings': totalBookings,
        'base_price': basePrice,
        'is_active': isActive,
        'is_verified': isVerified,
        'location_city': locationCity,
        'location_state': locationState,
        'contact_phone': contactPhone,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  OfflinePanditProfile copyWith({
    String? id,
    String? userId,
    String? name,
    String? avatarUrl,
    String? bio,
    int? experienceYears,
    List<String>? languages,
    List<String>? specialties,
    double? rating,
    int? totalReviews,
    int? totalBookings,
    double? basePrice,
    bool? isActive,
    bool? isVerified,
    String? locationCity,
    String? locationState,
    String? contactPhone,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<OfflinePanditService>? services,
    List<OfflinePanditReview>? reviews,
  }) =>
      OfflinePanditProfile(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        experienceYears: experienceYears ?? this.experienceYears,
        languages: languages ?? this.languages,
        specialties: specialties ?? this.specialties,
        rating: rating ?? this.rating,
        totalReviews: totalReviews ?? this.totalReviews,
        totalBookings: totalBookings ?? this.totalBookings,
        basePrice: basePrice ?? this.basePrice,
        isActive: isActive ?? this.isActive,
        isVerified: isVerified ?? this.isVerified,
        locationCity: locationCity ?? this.locationCity,
        locationState: locationState ?? this.locationState,
        contactPhone: contactPhone ?? this.contactPhone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        services: services ?? this.services,
        reviews: reviews ?? this.reviews,
      );
}

// ── Offline Booking ───────────────────────────────────────────────────────────────────

class OfflineBooking {
  const OfflineBooking({
    required this.id,
    required this.userId,
    required this.panditId,
    this.serviceId,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    this.landmark,
    required this.bookingDate,
    required this.bookingTime,
    this.durationMinutes = 60,
    required this.serviceName,
    this.serviceDescription,
    required this.amount,
    this.platformFee = 0.0,
    this.panditPayout = 0.0,
    required this.status,
    this.isPaid = false,
    this.paymentId,
    this.paymentStatus = 'pending',
    this.paidAt,
    this.contactVisible = false,
    this.panditContactPhone,
    this.specialRequirements,
    this.userNotes,
    this.panditNotes,
    this.adminNotes,
    this.isFlagged = false,
    this.flagReason,
    required this.createdAt,
    this.updatedAt,
    this.acceptedAt,
    this.completedAt,
    this.cancelledAt,
    this.panditName,
    this.panditAvatarUrl,
  });

  final String id;
  final String userId;
  final String panditId;
  final String? serviceId;
  
  // Address
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String pincode;
  final String? landmark;
  
  // Schedule
  final DateTime bookingDate;
  final String bookingTime;
  final int durationMinutes;
  
  // Service details
  final String serviceName;
  final String? serviceDescription;
  
  // Pricing
  final double amount;
  final double platformFee;
  final double panditPayout;
  
  // Status
  final OfflineBookingStatus status;
  
  // Payment
  final bool isPaid;
  final String? paymentId;
  final String paymentStatus;
  final DateTime? paidAt;
  
  // Contact visibility
  final bool contactVisible;
  final String? panditContactPhone;
  
  // Notes
  final String? specialRequirements;
  final String? userNotes;
  final String? panditNotes;
  final String? adminNotes;
  
  // Admin controls
  final bool isFlagged;
  final String? flagReason;
  
  // Timestamps
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  
  // Pandit info (for display)
  final String? panditName;
  final String? panditAvatarUrl;

  String get formattedDate {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${bookingDate.day} ${months[bookingDate.month - 1]} ${bookingDate.year}';
  }

  String get fullAddress {
    final parts = [
      addressLine1,
      if (addressLine2 != null && addressLine2!.isNotEmpty) addressLine2,
      if (landmark != null && landmark!.isNotEmpty) landmark,
      city,
      state,
      pincode,
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  String get amountLabel => '₹${amount.toStringAsFixed(0)}';

  factory OfflineBooking.fromJson(Map<String, dynamic> json) {
    return OfflineBooking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      panditId: json['pandit_id'] as String,
      serviceId: json['service_id'] as String?,
      addressLine1: json['address_line1'] as String,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String,
      state: json['state'] as String,
      pincode: json['pincode'] as String,
      landmark: json['landmark'] as String?,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      bookingTime: json['booking_time'] as String,
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      serviceName: json['service_name'] as String,
      serviceDescription: json['service_description'] as String?,
      amount: (json['amount'] as num).toDouble(),
      platformFee: (json['platform_fee'] as num?)?.toDouble() ?? 0.0,
      panditPayout: (json['pandit_payout'] as num?)?.toDouble() ?? 0.0,
      status: bookingStatusFromDb(json['status'] as String),
      isPaid: json['is_paid'] as bool? ?? false,
      paymentId: json['payment_id'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      contactVisible: json['contact_visible'] as bool? ?? false,
      panditContactPhone: json['pandit_contact_phone'] as String?,
      specialRequirements: json['special_requirements'] as String?,
      userNotes: json['user_notes'] as String?,
      panditNotes: json['pandit_notes'] as String?,
      adminNotes: json['admin_notes'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
      flagReason: json['flag_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
      panditName: json['pandit_name'] as String?,
      panditAvatarUrl: json['pandit_avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'pandit_id': panditId,
        'service_id': serviceId,
        'address_line1': addressLine1,
        'address_line2': addressLine2,
        'city': city,
        'state': state,
        'pincode': pincode,
        'landmark': landmark,
        'booking_date': bookingDate.toIso8601String(),
        'booking_time': bookingTime,
        'duration_minutes': durationMinutes,
        'service_name': serviceName,
        'service_description': serviceDescription,
        'amount': amount,
        'platform_fee': platformFee,
        'pandit_payout': panditPayout,
        'status': status.value,
        'is_paid': isPaid,
        'payment_id': paymentId,
        'payment_status': paymentStatus,
        'paid_at': paidAt?.toIso8601String(),
        'contact_visible': contactVisible,
        'pandit_contact_phone': panditContactPhone,
        'special_requirements': specialRequirements,
        'user_notes': userNotes,
        'pandit_notes': panditNotes,
        'admin_notes': adminNotes,
        'is_flagged': isFlagged,
        'flag_reason': flagReason,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'accepted_at': acceptedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
      };

  OfflineBooking copyWith({
    String? id,
    String? userId,
    String? panditId,
    String? serviceId,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? pincode,
    String? landmark,
    DateTime? bookingDate,
    String? bookingTime,
    int? durationMinutes,
    String? serviceName,
    String? serviceDescription,
    double? amount,
    double? platformFee,
    double? panditPayout,
    OfflineBookingStatus? status,
    bool? isPaid,
    String? paymentId,
    String? paymentStatus,
    DateTime? paidAt,
    bool? contactVisible,
    String? panditContactPhone,
    String? specialRequirements,
    String? userNotes,
    String? panditNotes,
    String? adminNotes,
    bool? isFlagged,
    String? flagReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? panditName,
    String? panditAvatarUrl,
  }) =>
      OfflineBooking(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        panditId: panditId ?? this.panditId,
        serviceId: serviceId ?? this.serviceId,
        addressLine1: addressLine1 ?? this.addressLine1,
        addressLine2: addressLine2 ?? this.addressLine2,
        city: city ?? this.city,
        state: state ?? this.state,
        pincode: pincode ?? this.pincode,
        landmark: landmark ?? this.landmark,
        bookingDate: bookingDate ?? this.bookingDate,
        bookingTime: bookingTime ?? this.bookingTime,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        serviceName: serviceName ?? this.serviceName,
        serviceDescription: serviceDescription ?? this.serviceDescription,
        amount: amount ?? this.amount,
        platformFee: platformFee ?? this.platformFee,
        panditPayout: panditPayout ?? this.panditPayout,
        status: status ?? this.status,
        isPaid: isPaid ?? this.isPaid,
        paymentId: paymentId ?? this.paymentId,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paidAt: paidAt ?? this.paidAt,
        contactVisible: contactVisible ?? this.contactVisible,
        panditContactPhone: panditContactPhone ?? this.panditContactPhone,
        specialRequirements: specialRequirements ?? this.specialRequirements,
        userNotes: userNotes ?? this.userNotes,
        panditNotes: panditNotes ?? this.panditNotes,
        adminNotes: adminNotes ?? this.adminNotes,
        isFlagged: isFlagged ?? this.isFlagged,
        flagReason: flagReason ?? this.flagReason,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        completedAt: completedAt ?? this.completedAt,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        panditName: panditName ?? this.panditName,
        panditAvatarUrl: panditAvatarUrl ?? this.panditAvatarUrl,
      );
}
