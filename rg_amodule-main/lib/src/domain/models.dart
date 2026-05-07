enum UserRole { user, pandit, admin }

enum BookingType { offlinePandit, poojaPackage, specialPooja, chat }

enum BookingStatus {
  pending,
  confirmed,
  panditAssigned,
  inProgress,
  processing,
  completed,
  cancelled,
  expired,
}

enum PaymentMethod { wallet, razorpay }

enum LedgerType { credit, debit }

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;
}

class Address {
  const Address({
    required this.id,
    required this.userId,
    required this.label,
    required this.line1,
    required this.city,
    required this.state,
    required this.pincode,
    this.isDefault = false,
  });

  final String id;
  final String userId;
  final String label;
  final String line1;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  String get full => '$line1, $city, $state - $pincode';
  String get rough {
    final place = [
      city,
      state,
    ].where((part) => part.trim().isNotEmpty).join(', ');
    return pincode.trim().isEmpty ? place : '$place - $pincode';
  }
}

class PanditProfile {
  const PanditProfile({
    required this.id,
    required this.name,
    required this.specialties,
    required this.languages,
    required this.rating,
    required this.completedBookings,
    required this.chatPricePerMinute,
    this.isOnline = true,
  });

  final String id;
  final String name;
  final List<String> specialties;
  final List<String> languages;
  final double rating;
  final int completedBookings;
  final int chatPricePerMinute;
  final bool isOnline;
}

class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.includedItems = const [],
    this.durationMinutes = 60,
    this.stock,
    this.isActive = true,
    this.sortOrder = 0,
    this.panditCoverage = 'One certified pandit',
    this.samigriIncluded = true,
  });

  final String id;
  final String title;
  final String description;
  final int price;
  final String imageUrl;
  final List<String> includedItems;
  final int durationMinutes;
  final int? stock;
  final bool isActive;
  final int sortOrder;
  final String panditCoverage;
  final bool samigriIncluded;

  CatalogueItem copyWith({
    String? id,
    String? title,
    String? description,
    int? price,
    String? imageUrl,
    List<String>? includedItems,
    int? durationMinutes,
    int? stock,
    bool? isActive,
    int? sortOrder,
    String? panditCoverage,
    bool? samigriIncluded,
  }) {
    return CatalogueItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      includedItems: includedItems ?? this.includedItems,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      stock: stock ?? this.stock,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      panditCoverage: panditCoverage ?? this.panditCoverage,
      samigriIncluded: samigriIncluded ?? this.samigriIncluded,
    );
  }
}

class Booking {
  const Booking({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.amount,
    required this.status,
    required this.scheduledAt,
    this.address,
    this.panditId,
    this.notes = '',
    this.paymentId,
    this.createdAt,
  });

  final String id;
  final String userId;
  final BookingType type;
  final String title;
  final int amount;
  final BookingStatus status;
  final DateTime scheduledAt;
  final Address? address;
  final String? panditId;
  final String notes;
  final String? paymentId;
  final DateTime? createdAt;

  String get panditSafeAddress => address?.rough ?? 'Online service';

  Booking copyWith({
    BookingStatus? status,
    String? panditId,
    String? paymentId,
    String? notes,
  }) {
    return Booking(
      id: id,
      userId: userId,
      type: type,
      title: title,
      amount: amount,
      status: status ?? this.status,
      scheduledAt: scheduledAt,
      address: address,
      panditId: panditId ?? this.panditId,
      notes: notes ?? this.notes,
      paymentId: paymentId ?? this.paymentId,
      createdAt: createdAt,
    );
  }
}

class StatusEntry {
  const StatusEntry({
    required this.bookingId,
    required this.status,
    required this.changedBy,
    required this.createdAt,
    this.note = '',
  });

  final String bookingId;
  final BookingStatus status;
  final String changedBy;
  final DateTime createdAt;
  final String note;
}

class Wallet {
  const Wallet({required this.userId, required this.balance});

  final String userId;
  final int balance;
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.userId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    required this.createdAt,
    this.referenceId,
  });

  final String id;
  final String userId;
  final LedgerType type;
  final int amount;
  final int balanceAfter;
  final String reason;
  final DateTime createdAt;
  final String? referenceId;
}

class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.referenceId,
    this.providerOrderId,
    this.providerPaymentId,
    this.providerSignature,
  });

  final String id;
  final String userId;
  final int amount;
  final PaymentMethod method;
  final String status;
  final DateTime createdAt;
  final String? referenceId;
  final String? providerOrderId;
  final String? providerPaymentId;
  final String? providerSignature;
}

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final CatalogueItem item;
  final int quantity;
  int get total => item.price * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(item: item, quantity: quantity ?? this.quantity);
  }
}

class ShopOrder {
  const ShopOrder({
    required this.id,
    required this.userId,
    required this.lines,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final List<CartLine> lines;
  final int total;
  final String status;
  final DateTime createdAt;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.imageUrl,
    this.isRead = false,
  });

  final String id;
  final String sessionId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String? imageUrl;
  final bool isRead;
}

class ChatSession {
  const ChatSession({
    required this.id,
    required this.userId,
    required this.panditId,
    required this.startedAt,
    required this.endsAt,
    required this.price,
    this.status = BookingStatus.inProgress,
  });

  final String id;
  final String userId;
  final String panditId;
  final DateTime startedAt;
  final DateTime endsAt;
  final int price;
  final BookingStatus status;

  Duration remaining(DateTime now) {
    final left = endsAt.difference(now);
    return left.isNegative ? Duration.zero : left;
  }

  bool isNearEnd(DateTime now) => remaining(now).inSeconds <= 120;
  bool get isActive => status == BookingStatus.inProgress;

  ChatSession copyWith({DateTime? endsAt, BookingStatus? status}) {
    return ChatSession(
      id: id,
      userId: userId,
      panditId: panditId,
      startedAt: startedAt,
      endsAt: endsAt ?? this.endsAt,
      price: price,
      status: status ?? this.status,
    );
  }
}

class ProofVideo {
  const ProofVideo({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.mediaUrl,
    required this.storageKey,
    required this.uploadedAt,
    required this.expiresAt,
    required this.sizeBytes,
  });

  final String id;
  final String bookingId;
  final String userId;
  final String mediaUrl;
  final String storageKey;
  final DateTime uploadedAt;
  final DateTime expiresAt;
  final int sizeBytes;

  bool isAvailable(DateTime now) => now.isBefore(expiresAt);
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
}
