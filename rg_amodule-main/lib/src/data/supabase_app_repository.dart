import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'app_repository.dart';
import 'services.dart';

class SupabaseAppRepository implements AppRepository {
  SupabaseAppRepository({
    required SupabaseClient client,
    required PaymentService paymentService,
    required MediaStorageService mediaStorage,
  }) : _client = client,
       _paymentService = paymentService,
       _mediaStorage = mediaStorage;

  final SupabaseClient _client;
  final PaymentService _paymentService;
  final MediaStorageService _mediaStorage;

  AppUser _currentUser = const AppUser(
    id: '',
    name: 'Guest',
    email: '',
    role: UserRole.user,
  );
  final _users = <AppUser>[];
  final _pandits = <PanditProfile>[];
  final _packages = <CatalogueItem>[];
  final _special = <CatalogueItem>[];
  final _shop = <CatalogueItem>[];
  final _bookings = <Booking>[];
  final _addresses = <Address>[];
  final _orders = <ShopOrder>[];
  final _ledger = <WalletLedgerEntry>[];
  final _cart = <CartLine>[];
  final _messages = <String, List<ChatMessage>>{};
  final _sessions = <String, ChatSession>{};
  final _proofs = <ProofVideo>[];
  final _notifications = <AppNotification>[];
  int _walletBalance = 0;

  @override
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  AppUser get currentUser => _currentUser;
  @override
  List<AppUser> get users => List.unmodifiable(_users);
  @override
  List<PanditProfile> get pandits => List.unmodifiable(_pandits);
  @override
  List<CatalogueItem> get poojaPackages => List.unmodifiable(_packages);
  @override
  List<CatalogueItem> get specialPoojas => List.unmodifiable(_special);
  @override
  List<CatalogueItem> get shopItems => List.unmodifiable(_shop);
  @override
  List<Booking> get bookings => List.unmodifiable(_bookings);
  @override
  List<ShopOrder> get orders => List.unmodifiable(_orders);
  @override
  List<AppNotification> get notifications => List.unmodifiable(_notifications);

  @override
  List<Address> addressesFor(String userId) =>
      List.unmodifiable(_addresses.where((entry) => entry.userId == userId));

  @override
  Wallet walletFor(String userId) => Wallet(
    userId: userId,
    balance: userId == _currentUser.id ? _walletBalance : 0,
  );

  @override
  List<WalletLedgerEntry> ledgerFor(String userId) =>
      List.unmodifiable(_ledger.where((entry) => entry.userId == userId));

  @override
  List<CartLine> cartFor(String userId) =>
      userId == _currentUser.id ? List.unmodifiable(_cart) : const [];

  @override
  ChatSession? chatSessionById(String sessionId) => _sessions[sessionId];

  @override
  List<ChatMessage> messagesFor(String sessionId) =>
      List.unmodifiable(_messages[sessionId] ?? const []);

  @override
  List<ProofVideo> proofsFor(String userId, DateTime now) => List.unmodifiable(
    _proofs.where((proof) => proof.userId == userId && proof.isAvailable(now)),
  );

  @override
  Stream<List<Booking>> bookingStream(String userId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(_bookingFromJson).toList());
  }

  @override
  Stream<List<ChatMessage>> chatStream(String sessionId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId)
        .order('created_at')
        .map((rows) => rows.map(_chatMessageFromJson).toList());
  }

  @override
  Future<void> reload() async {
    if (!isAuthenticated) return;
    await _loadCurrentUser();
    await Future.wait([
      _loadUsersIfAdmin(),
      _loadPandits(),
      _loadCatalogues(),
      _loadAddresses(),
      _loadBookings(),
      _loadWallet(),
      _loadCart(),
      _loadOrders(),
      _loadProofs(),
      _loadNotifications(),
    ]);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) {
      throw const AppException('Unable to sign in.');
    }
    await reload();
    return _currentUser;
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'phone': phone, 'role': 'user'},
    );
    final user = response.user;
    if (user == null) throw const AppException('Unable to create account.');
    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': name,
      'email': email,
      'phone': phone,
      'role': 'user',
    });
    await reload();
    return _currentUser;
  }

  @override
  Future<AppUser> signInAs(UserRole role) async {
    throw const AppException('Demo role switching is disabled in production.');
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentUser = const AppUser(
      id: '',
      name: 'Guest',
      email: '',
      role: UserRole.user,
    );
    _walletBalance = 0;
    _bookings.clear();
    _cart.clear();
  }

  @override
  Future<Address> saveAddress(Address address) async {
    _requireSignedIn();
    final saved = await _client
        .from('addresses')
        .upsert({
          'id': address.id.isEmpty ? null : address.id,
          'user_id': _currentUser.id,
          'label': address.label,
          'line1': address.line1,
          'city': address.city,
          'state': address.state,
          'pincode': address.pincode,
          'is_default': address.isDefault,
        })
        .select()
        .single();
    await _loadAddresses();
    return _addressFromJson(saved);
  }

  @override
  Future<void> topUpWallet(String userId, int amount) async {
    _requireSignedIn();
    final payment = await _paymentService.pay(
      userId: userId,
      amount: amount,
      method: PaymentMethod.razorpay,
      referenceId: 'wallet_topup',
    );
    final paymentRow = await _client
        .from('payments')
        .insert({
          'user_id': userId,
          'amount': amount,
          'method': 'razorpay',
          'status': payment.status,
          'reference_type': 'wallet_topup',
          'razorpay_order_id': payment.providerOrderId ?? payment.id,
          'razorpay_payment_id': payment.providerPaymentId,
          'razorpay_signature': payment.providerSignature,
          'raw_payload': {
            'payment_id': payment.providerPaymentId ?? payment.id,
          },
        })
        .select('id')
        .single();
    await _client.rpc(
      'credit_paid_wallet_topup',
      params: {'p_payment_id': paymentRow['id']},
    );
    await _client.from('notifications').insert({
      'user_id': userId,
      'title': 'Wallet top-up success',
      'body': 'Your wallet was credited with Rs $amount.',
    });
    await _loadWallet();
  }

  @override
  Future<Booking> createBooking({
    required BookingType type,
    required String catalogueId,
    required DateTime scheduledAt,
    required PaymentMethod paymentMethod,
    Address? address,
    String notes = '',
  }) async {
    _requireSignedIn();
    final item = _catalogueForType(
      type,
    ).firstWhere((entry) => entry.id == catalogueId);
    if ((type == BookingType.offlinePandit ||
            type == BookingType.poojaPackage) &&
        address == null) {
      throw const AppException('A service address is required.');
    }
    final bookingId = _uuid();
    final paymentId = await _capturePayment(
      userId: _currentUser.id,
      amount: item.price,
      method: paymentMethod,
      referenceId: bookingId,
      reason: 'Booking ${item.title}',
    );
    final row = await _client
        .from('bookings')
        .insert({
          'id': bookingId,
          'user_id': _currentUser.id,
          'booking_type': _bookingTypeToDb(type),
          'catalogue_id': catalogueId,
          'title': item.title,
          'amount': item.price,
          'status': type == BookingType.specialPooja ? 'processing' : 'pending',
          'scheduled_at': scheduledAt.toIso8601String(),
          'address_id': address?.id,
          'address_snapshot': address == null ? null : _addressToJson(address),
          'rough_address': address?.rough,
          'payment_id': paymentId,
          'user_notes': notes,
        })
        .select()
        .single();
    await _client.from('booking_status_history').insert({
      'booking_id': bookingId,
      'status': row['status'],
      'changed_by': _currentUser.id,
      'note': 'Created after payment',
    });
    await _client.from('notifications').insert({
      'user_id': _currentUser.id,
      'title': 'Booking confirmed',
      'body': '${item.title} has been booked.',
    });
    final booking = _bookingFromJson(row);
    await _loadBookings();
    return booking;
  }

  @override
  Future<Booking> adminUpdateBooking({
    required String bookingId,
    required BookingStatus status,
    String? panditId,
    String note = '',
  }) async {
    _requireSignedIn();
    if (_currentUser.role == UserRole.pandit && panditId == null) {
      final row = await _client
          .rpc(
            'complete_assigned_booking',
            params: {
              'p_booking_id': bookingId,
              'p_status': _statusToDb(status),
              'p_note': note,
            },
          )
          .single();
      await _loadBookings();
      return _bookingFromJson(row);
    }
    final payload = <String, dynamic>{
      'status': _statusToDb(status),
      'pandit_notes': note.isEmpty ? null : note,
    };
    if (panditId != null) payload['pandit_id'] = panditId;
    final row = await _client
        .from('bookings')
        .update(payload)
        .eq('id', bookingId)
        .select()
        .single();
    await _client.from('booking_status_history').insert({
      'booking_id': bookingId,
      'status': _statusToDb(status),
      'changed_by': _currentUser.id,
      'note': note,
    });
    await _client.from('notifications').insert({
      'user_id': row['user_id'],
      'title': 'Booking status updated',
      'body': '${row['title']} is now ${status.name}.',
    });
    await _loadBookings();
    return _bookingFromJson(row);
  }

  @override
  Future<ChatSession> bookChatSession({
    required String panditId,
    required int minutes,
    required PaymentMethod paymentMethod,
  }) async {
    _requireSignedIn();
    final pandit = _pandits.firstWhere((entry) => entry.id == panditId);
    final price = pandit.chatPricePerMinute * minutes;
    final sessionId = _uuid();
    await _capturePayment(
      userId: _currentUser.id,
      amount: price,
      method: paymentMethod,
      referenceId: sessionId,
      reason: '$minutes minute astrology chat',
    );
    final now = DateTime.now().toUtc();
    final row = await _client
        .from('chat_sessions')
        .insert({
          'id': sessionId,
          'user_id': _currentUser.id,
          'pandit_id': panditId,
          'started_at': now.toIso8601String(),
          'ends_at': now.add(Duration(minutes: minutes)).toIso8601String(),
          'status': 'in_progress',
          'price': price,
        })
        .select()
        .single();
    await _client.from('chat_messages').insert({
      'session_id': sessionId,
      'sender_id': panditId,
      'body': 'Namaste. Please share your question and image for review.',
    });
    final session = _chatSessionFromJson(row);
    _sessions[session.id] = session;
    await _loadMessages(session.id);
    return session;
  }

  @override
  Future<ChatSession> extendChatSession({
    required String sessionId,
    required int minutes,
    required PaymentMethod paymentMethod,
  }) async {
    _requireSignedIn();
    final session =
        _sessions[sessionId] ??
        _chatSessionFromJson(
          await _client
              .from('chat_sessions')
              .select()
              .eq('id', sessionId)
              .single(),
        );
    final pandit = _pandits.firstWhere((entry) => entry.id == session.panditId);
    await _capturePayment(
      userId: session.userId,
      amount: pandit.chatPricePerMinute * minutes,
      method: paymentMethod,
      referenceId: sessionId,
      reason: 'Chat extension',
    );
    final row = await _client
        .from('chat_sessions')
        .update({
          'ends_at': session.endsAt
              .add(Duration(minutes: minutes))
              .toIso8601String(),
        })
        .eq('id', sessionId)
        .select()
        .single();
    final updated = _chatSessionFromJson(row);
    _sessions[sessionId] = updated;
    return updated;
  }

  @override
  Future<ChatMessage> sendChatMessage({
    required String sessionId,
    required String text,
    Uint8List? imageBytes,
  }) async {
    _requireSignedIn();
    final row = await _client
        .from('chat_messages')
        .insert({
          'session_id': sessionId,
          'sender_id': _currentUser.id,
          'body': text,
        })
        .select()
        .single();
    String? imageUrl;
    if (imageBytes != null) {
      imageUrl = await _mediaStorage.uploadBytes(
        folder: 'chat/$sessionId',
        fileName: '${row['id']}.jpg',
        bytes: imageBytes,
        contentType: 'image/jpeg',
        maxBytes: 10 * 1024 * 1024,
      );
      await _client.from('chat_attachments').insert({
        'message_id': row['id'],
        'storage_key': imageUrl,
        'signed_url': imageUrl,
        'content_type': 'image/jpeg',
        'size_bytes': imageBytes.length,
      });
    }
    final message = _chatMessageFromJson({...row, 'image_url': imageUrl});
    await _loadMessages(sessionId);
    return message;
  }

  @override
  Future<void> addToCart(String itemId, int quantity) async {
    _requireSignedIn();
    final cartId = await _ensureCart();
    final existing = await _client
        .from('cart_items')
        .select()
        .eq('cart_id', cartId)
        .eq('item_id', itemId)
        .maybeSingle();
    if (existing == null) {
      await _client.from('cart_items').insert({
        'cart_id': cartId,
        'item_id': itemId,
        'quantity': quantity,
      });
    } else {
      await _client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('id', existing['id']);
    }
    await _loadCart();
  }

  @override
  Future<void> updateCart(String itemId, int quantity) async {
    _requireSignedIn();
    final cartId = await _ensureCart();
    if (quantity <= 0) {
      await _client
          .from('cart_items')
          .delete()
          .eq('cart_id', cartId)
          .eq('item_id', itemId);
    } else {
      await _client
          .from('cart_items')
          .update({'quantity': quantity})
          .eq('cart_id', cartId)
          .eq('item_id', itemId);
    }
    await _loadCart();
  }

  @override
  Future<ShopOrder> checkoutCart(PaymentMethod paymentMethod) async {
    _requireSignedIn();
    if (_cart.isEmpty) throw const AppException('Cart is empty.');
    final lines = List<CartLine>.from(_cart);
    final total = lines.fold<int>(0, (sum, line) => sum + line.total);
    final orderId = _uuid();
    final paymentId = await _capturePayment(
      userId: _currentUser.id,
      amount: total,
      method: paymentMethod,
      referenceId: orderId,
      reason: 'Shop order',
    );
    final orderRow = await _client
        .from('orders')
        .insert({
          'id': orderId,
          'user_id': _currentUser.id,
          'total': total,
          'status': 'confirmed',
          'payment_id': paymentId,
        })
        .select()
        .single();
    await _client
        .from('order_items')
        .insert(
          lines.map((line) {
            return {
              'order_id': orderId,
              'item_id': line.item.id,
              'title': line.item.title,
              'unit_price': line.item.price,
              'quantity': line.quantity,
            };
          }).toList(),
        );
    final cartId = await _ensureCart();
    await _client.from('cart_items').delete().eq('cart_id', cartId);
    await _loadCart();
    await _loadOrders();
    return _orderFromJson(orderRow, lines);
  }

  @override
  Future<CatalogueItem> upsertCatalogue({
    required String area,
    required CatalogueItem item,
  }) async {
    final table = _tableForArea(area);
    final row = await _client
        .from(table)
        .upsert(_catalogueToJson(item))
        .select()
        .single();
    await _loadCatalogues();
    return _catalogueFromJson(row);
  }

  @override
  Future<void> deleteCatalogue({
    required String area,
    required String id,
  }) async {
    await _client
        .from(_tableForArea(area))
        .update({'is_active': false})
        .eq('id', id);
    await _loadCatalogues();
  }

  @override
  Future<ProofVideo> uploadProofVideo({
    required String bookingId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.length > 300 * 1024 * 1024) {
      throw const AppException('Proof video must be 300 MB or smaller.');
    }
    final booking = _bookings.firstWhere((entry) => entry.id == bookingId);
    final url = await _mediaStorage.uploadBytes(
      folder: 'proofs/$bookingId',
      fileName: fileName,
      bytes: bytes,
      contentType: 'video/mp4',
      maxBytes: 300 * 1024 * 1024,
    );
    final row = await _client
        .from('proof_videos')
        .upsert({
          'booking_id': bookingId,
          'user_id': booking.userId,
          'uploaded_by': _currentUser.id,
          'storage_key': url,
          'signed_url': url,
          'size_bytes': bytes.length,
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 7))
              .toIso8601String(),
        })
        .select()
        .single();
    await _client.from('notifications').insert({
      'user_id': booking.userId,
      'title': 'Proof video available',
      'body': 'Download your special pooja proof within 7 days.',
    });
    final proof = _proofFromJson(row);
    await _loadProofs();
    return proof;
  }

  Future<void> _loadCurrentUser() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return;
    final row = await _client
        .from('profiles')
        .select()
        .eq('id', authUser.id)
        .single();
    _currentUser = _userFromJson(row, authUser.email);
  }

  Future<void> _loadUsersIfAdmin() async {
    _users.clear();
    if (_currentUser.role != UserRole.admin) return;
    final rows = await _client.from('profiles').select().order('created_at');
    _users.addAll(rows.map((row) => _userFromJson(row)));
  }

  Future<void> _loadPandits() async {
    final rows = await _client
        .from('pandits')
        .select('*, profiles(full_name)')
        .order('rating');
    _pandits
      ..clear()
      ..addAll(rows.map(_panditFromJson));
  }

  Future<void> _loadCatalogues() async {
    final results = await Future.wait([
      _client.from('pooja_packages').select().order('sort_order'),
      _client.from('special_poojas').select().order('sort_order'),
      _client.from('shop_items').select().order('sort_order'),
    ]);
    _packages
      ..clear()
      ..addAll(results[0].map(_catalogueFromJson));
    _special
      ..clear()
      ..addAll(results[1].map(_catalogueFromJson));
    _shop
      ..clear()
      ..addAll(results[2].map(_catalogueFromJson));
  }

  Future<void> _loadBookings() async {
    final rows = _currentUser.role == UserRole.pandit
        ? await _client
              .from('pandit_booking_assignments')
              .select()
              .order('created_at')
        : await _client.from('bookings').select().order('created_at');
    _bookings
      ..clear()
      ..addAll(rows.map(_bookingFromJson));
  }

  Future<void> _loadAddresses() async {
    final rows = await _client
        .from('addresses')
        .select()
        .eq('user_id', _currentUser.id)
        .order('is_default', ascending: false);
    _addresses
      ..clear()
      ..addAll(rows.map(_addressFromJson));
  }

  Future<void> _loadWallet() async {
    final wallet = await _client
        .from('wallets')
        .select()
        .eq('user_id', _currentUser.id)
        .maybeSingle();
    _walletBalance = (wallet?['balance'] as int?) ?? 0;
    final rows = await _client
        .from('wallet_ledger')
        .select()
        .eq('user_id', _currentUser.id)
        .order('created_at');
    _ledger
      ..clear()
      ..addAll(rows.map(_ledgerFromJson));
  }

  Future<void> _loadCart() async {
    _cart.clear();
    final cart = await _client
        .from('carts')
        .select()
        .eq('user_id', _currentUser.id)
        .maybeSingle();
    if (cart == null) return;
    final rows = await _client
        .from('cart_items')
        .select('quantity, shop_items(*)')
        .eq('cart_id', cart['id']);
    _cart.addAll(
      rows.map((row) {
        return CartLine(
          item: _catalogueFromJson(row['shop_items']),
          quantity: row['quantity'] as int,
        );
      }),
    );
  }

  Future<void> _loadOrders() async {
    final rows = await _client.from('orders').select().order('created_at');
    _orders
      ..clear()
      ..addAll(rows.map((row) => _orderFromJson(row, const [])));
  }

  Future<void> _loadProofs() async {
    final rows = await _client
        .from('proof_videos')
        .select()
        .order('uploaded_at');
    _proofs
      ..clear()
      ..addAll(rows.map(_proofFromJson));
  }

  Future<void> _loadNotifications() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at');
    _notifications
      ..clear()
      ..addAll(rows.map(_notificationFromJson));
  }

  Future<void> _loadMessages(String sessionId) async {
    final rows = await _client
        .from('chat_messages')
        .select()
        .eq('session_id', sessionId)
        .order('created_at');
    _messages[sessionId] = rows.map(_chatMessageFromJson).toList();
  }

  Future<String> _capturePayment({
    required String userId,
    required int amount,
    required PaymentMethod method,
    required String referenceId,
    required String reason,
  }) async {
    if (method == PaymentMethod.wallet) {
      await _client.rpc(
        'wallet_apply',
        params: {
          'p_user_id': userId,
          'p_type': 'debit',
          'p_amount': amount,
          'p_reason': reason,
          'p_reference_id': referenceId,
        },
      );
      final row = await _client
          .from('payments')
          .insert({
            'user_id': userId,
            'amount': amount,
            'method': 'wallet',
            'status': 'captured',
            'reference_id': referenceId,
            'raw_payload': {'reason': reason},
          })
          .select('id')
          .single();
      await _loadWallet();
      return row['id'] as String;
    }
    final payment = await _paymentService.pay(
      userId: userId,
      amount: amount,
      method: method,
      referenceId: referenceId,
    );
    final row = await _client
        .from('payments')
        .insert({
          'user_id': userId,
          'amount': amount,
          'method': 'razorpay',
          'status': payment.status,
          'razorpay_order_id': payment.providerOrderId ?? payment.id,
          'razorpay_payment_id': payment.providerPaymentId,
          'razorpay_signature': payment.providerSignature,
          'reference_id': referenceId,
          'raw_payload': {
            'payment_id': payment.providerPaymentId ?? payment.id,
          },
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<String> _ensureCart() async {
    final row = await _client
        .from('carts')
        .upsert({'user_id': _currentUser.id}, onConflict: 'user_id')
        .select()
        .single();
    return row['id'] as String;
  }

  List<CatalogueItem> _catalogueForType(BookingType type) {
    return switch (type) {
      BookingType.specialPooja => _special,
      BookingType.offlinePandit || BookingType.poojaPackage => _packages,
      BookingType.chat => _packages,
    };
  }

  void _requireSignedIn() {
    if (!isAuthenticated) throw const AppException('Please sign in first.');
  }

  String _uuid() => const Uuid().v4();

  static AppUser _userFromJson(
    Map<String, dynamic> row, [
    String? fallbackEmail,
  ]) {
    return AppUser(
      id: row['id'] as String,
      name: (row['full_name'] as String?) ?? 'User',
      email: (row['email'] as String?) ?? fallbackEmail ?? '',
      phone: row['phone'] as String?,
      role: _roleFromDb((row['role'] as String?) ?? 'user'),
    );
  }

  static PanditProfile _panditFromJson(Map<String, dynamic> row) {
    final profile = row['profiles'];
    return PanditProfile(
      id: row['id'] as String,
      name: profile is Map
          ? (profile['full_name'] as String? ?? 'Pandit')
          : 'Pandit',
      specialties: List<String>.from(row['specialties'] as List? ?? const []),
      languages: List<String>.from(row['languages'] as List? ?? const []),
      rating: ((row['rating'] as num?) ?? 0).toDouble(),
      completedBookings: (row['completed_bookings'] as int?) ?? 0,
      chatPricePerMinute: (row['chat_price_per_minute'] as int?) ?? 20,
      isOnline: (row['is_online'] as bool?) ?? false,
    );
  }

  static CatalogueItem _catalogueFromJson(Map<String, dynamic> row) {
    return CatalogueItem(
      id: row['id'] as String,
      title: (row['title'] as String?) ?? '',
      description: (row['description'] as String?) ?? '',
      price: (row['price'] as int?) ?? 0,
      imageUrl: (row['image_url'] as String?) ?? '',
      includedItems: List<String>.from(
        row['included_items'] as List? ?? const [],
      ),
      durationMinutes: (row['duration_minutes'] as int?) ?? 60,
      stock: row['stock'] as int?,
      isActive: (row['is_active'] as bool?) ?? true,
      sortOrder: (row['sort_order'] as int?) ?? 0,
      panditCoverage:
          (row['pandit_coverage'] as String?) ?? 'One certified pandit',
      samigriIncluded: (row['samigri_included'] as bool?) ?? true,
    );
  }

  static Booking _bookingFromJson(Map<String, dynamic> row) {
    final snapshot = row['address_snapshot'];
    final roughAddress = row['rough_address'] as String?;
    return Booking(
      id: row['id'] as String,
      userId: (row['user_id'] as String?) ?? '',
      type: _bookingTypeFromDb(row['booking_type'] as String),
      title: row['title'] as String,
      amount: (row['amount'] as int?) ?? 0,
      status: _statusFromDb(row['status'] as String),
      scheduledAt: DateTime.parse(row['scheduled_at'] as String),
      address: snapshot is Map
          ? _addressFromJson(Map<String, dynamic>.from(snapshot))
          : roughAddress == null
          ? null
          : Address(
              id: '',
              userId: '',
              label: 'Service area',
              line1: roughAddress,
              city: roughAddress,
              state: '',
              pincode: '',
            ),
      panditId: row['pandit_id'] as String?,
      notes: (row['user_notes'] as String?) ?? '',
      paymentId: row['payment_id'] as String?,
      createdAt: row['created_at'] == null
          ? null
          : DateTime.parse(row['created_at'] as String),
    );
  }

  static Address _addressFromJson(Map<String, dynamic> row) {
    return Address(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      label: (row['label'] as String?) ?? 'Address',
      line1: (row['line1'] as String?) ?? '',
      city: (row['city'] as String?) ?? '',
      state: (row['state'] as String?) ?? '',
      pincode: (row['pincode'] as String?) ?? '',
      isDefault: (row['is_default'] as bool?) ?? false,
    );
  }

  static Map<String, dynamic> _addressToJson(Address address) => {
    'id': address.id,
    'user_id': address.userId,
    'label': address.label,
    'line1': address.line1,
    'city': address.city,
    'state': address.state,
    'pincode': address.pincode,
    'is_default': address.isDefault,
  };

  static ChatSession _chatSessionFromJson(Map<String, dynamic> row) {
    return ChatSession(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      panditId: row['pandit_id'] as String,
      startedAt: DateTime.parse(row['started_at'] as String),
      endsAt: DateTime.parse(row['ends_at'] as String),
      price: row['price'] as int,
      status: _statusFromDb(row['status'] as String),
    );
  }

  static ChatMessage _chatMessageFromJson(Map<String, dynamic> row) {
    return ChatMessage(
      id: row['id'] as String,
      sessionId: row['session_id'] as String,
      senderId: row['sender_id'] as String,
      text: (row['body'] as String?) ?? '',
      imageUrl: row['image_url'] as String?,
      isRead: (row['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static WalletLedgerEntry _ledgerFromJson(Map<String, dynamic> row) {
    return WalletLedgerEntry(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      type: row['ledger_type'] == 'credit'
          ? LedgerType.credit
          : LedgerType.debit,
      amount: row['amount'] as int,
      balanceAfter: row['balance_after'] as int,
      reason: row['reason'] as String,
      referenceId: row['reference_id'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static ShopOrder _orderFromJson(
    Map<String, dynamic> row,
    List<CartLine> lines,
  ) {
    return ShopOrder(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      lines: List<CartLine>.from(lines),
      total: row['total'] as int,
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static ProofVideo _proofFromJson(Map<String, dynamic> row) {
    return ProofVideo(
      id: row['id'] as String,
      bookingId: row['booking_id'] as String,
      userId: row['user_id'] as String,
      mediaUrl: (row['signed_url'] as String?) ?? row['storage_key'] as String,
      storageKey: row['storage_key'] as String,
      uploadedAt: DateTime.parse(row['uploaded_at'] as String),
      expiresAt: DateTime.parse(row['expires_at'] as String),
      sizeBytes: row['size_bytes'] as int,
    );
  }

  static AppNotification _notificationFromJson(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      body: row['body'] as String,
      isRead: (row['is_read'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static Map<String, dynamic> _catalogueToJson(CatalogueItem item) => {
    'id': item.id.isEmpty ? null : item.id,
    'title': item.title,
    'description': item.description,
    'included_items': item.includedItems,
    'duration_minutes': item.durationMinutes,
    'price': item.price,
    'image_url': item.imageUrl,
    'stock': item.stock,
    'is_active': item.isActive,
    'sort_order': item.sortOrder,
    'pandit_coverage': item.panditCoverage,
    'samigri_included': item.samigriIncluded,
  }..removeWhere((_, value) => value == null);

  static String _tableForArea(String area) => switch (area) {
    'packages' => 'pooja_packages',
    'special' => 'special_poojas',
    'shop' => 'shop_items',
    _ => throw const AppException('Unknown catalogue area.'),
  };

  static UserRole _roleFromDb(String value) => switch (value) {
    'admin' => UserRole.admin,
    'pandit' => UserRole.pandit,
    _ => UserRole.user,
  };

  static BookingType _bookingTypeFromDb(String value) => switch (value) {
    'offline_pandit' => BookingType.offlinePandit,
    'special_pooja' => BookingType.specialPooja,
    'chat' => BookingType.chat,
    _ => BookingType.poojaPackage,
  };

  static String _bookingTypeToDb(BookingType value) => switch (value) {
    BookingType.offlinePandit => 'offline_pandit',
    BookingType.poojaPackage => 'pooja_package',
    BookingType.specialPooja => 'special_pooja',
    BookingType.chat => 'chat',
  };

  static BookingStatus _statusFromDb(String value) => switch (value) {
    'confirmed' => BookingStatus.confirmed,
    'pandit_assigned' => BookingStatus.panditAssigned,
    'in_progress' => BookingStatus.inProgress,
    'processing' => BookingStatus.processing,
    'completed' => BookingStatus.completed,
    'cancelled' => BookingStatus.cancelled,
    'expired' => BookingStatus.expired,
    _ => BookingStatus.pending,
  };

  static String _statusToDb(BookingStatus value) => switch (value) {
    BookingStatus.pending => 'pending',
    BookingStatus.confirmed => 'confirmed',
    BookingStatus.panditAssigned => 'pandit_assigned',
    BookingStatus.inProgress => 'in_progress',
    BookingStatus.processing => 'processing',
    BookingStatus.completed => 'completed',
    BookingStatus.cancelled => 'cancelled',
    BookingStatus.expired => 'expired',
  };
}
