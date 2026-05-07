import 'dart:async';
import 'dart:typed_data';

import '../domain/models.dart';
import 'services.dart';

abstract class AppRepository {
  bool get isAuthenticated;
  AppUser get currentUser;
  List<AppUser> get users;
  List<PanditProfile> get pandits;
  List<CatalogueItem> get poojaPackages;
  List<CatalogueItem> get specialPoojas;
  List<CatalogueItem> get shopItems;
  List<Booking> get bookings;
  List<ShopOrder> get orders;
  List<AppNotification> get notifications;
  List<Address> addressesFor(String userId);
  Wallet walletFor(String userId);
  List<WalletLedgerEntry> ledgerFor(String userId);
  List<CartLine> cartFor(String userId);
  ChatSession? chatSessionById(String sessionId);
  List<ChatMessage> messagesFor(String sessionId);
  List<ProofVideo> proofsFor(String userId, DateTime now);

  Stream<List<Booking>> bookingStream(String userId);
  Stream<List<ChatMessage>> chatStream(String sessionId);

  Future<void> reload();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  });
  Future<AppUser> signInAs(UserRole role);
  Future<void> signOut();
  Future<Address> saveAddress(Address address);
  Future<void> topUpWallet(String userId, int amount);
  Future<Booking> createBooking({
    required BookingType type,
    required String catalogueId,
    required DateTime scheduledAt,
    required PaymentMethod paymentMethod,
    Address? address,
    String notes,
  });
  Future<Booking> adminUpdateBooking({
    required String bookingId,
    required BookingStatus status,
    String? panditId,
    String note,
  });
  Future<ChatSession> bookChatSession({
    required String panditId,
    required int minutes,
    required PaymentMethod paymentMethod,
  });
  Future<ChatSession> extendChatSession({
    required String sessionId,
    required int minutes,
    required PaymentMethod paymentMethod,
  });
  Future<ChatMessage> sendChatMessage({
    required String sessionId,
    required String text,
    Uint8List? imageBytes,
  });
  Future<void> addToCart(String itemId, int quantity);
  Future<void> updateCart(String itemId, int quantity);
  Future<ShopOrder> checkoutCart(PaymentMethod paymentMethod);
  Future<CatalogueItem> upsertCatalogue({
    required String area,
    required CatalogueItem item,
  });
  Future<void> deleteCatalogue({required String area, required String id});
  Future<ProofVideo> uploadProofVideo({
    required String bookingId,
    required Uint8List bytes,
    required String fileName,
  });
}

class InMemoryAppRepository implements AppRepository {
  InMemoryAppRepository({
    required PaymentService paymentService,
    required MediaStorageService mediaStorage,
  }) : _paymentService = paymentService,
       _mediaStorage = mediaStorage {
    _seed();
  }

  final PaymentService _paymentService;
  final MediaStorageService _mediaStorage;
  final _bookingController = StreamController<List<Booking>>.broadcast();
  final _chatControllers = <String, StreamController<List<ChatMessage>>>{};
  final _users = <AppUser>[];
  final _addresses = <Address>[];
  final _pandits = <PanditProfile>[];
  final _packages = <CatalogueItem>[];
  final _special = <CatalogueItem>[];
  final _shop = <CatalogueItem>[];
  final _bookings = <Booking>[];
  final _statusHistory = <StatusEntry>[];
  final _wallets = <String, int>{};
  final _ledger = <WalletLedgerEntry>[];
  final _payments = <PaymentRecord>[];
  final _cart = <String, List<CartLine>>{};
  final _orders = <ShopOrder>[];
  final _sessions = <String, ChatSession>{};
  final _messages = <String, List<ChatMessage>>{};
  final _proofs = <ProofVideo>[];
  final _notifications = <AppNotification>[];
  late AppUser _currentUser;
  bool _authenticated = true;

  void _seed() {
    _users.addAll(const [
      AppUser(
        id: 'u1',
        name: 'Aarav Sharma',
        email: 'user@saralpooja.app',
        role: UserRole.user,
        phone: '+919999999991',
      ),
      AppUser(
        id: 'p1',
        name: 'Pt. Dev Mishra',
        email: 'pandit@saralpooja.app',
        role: UserRole.pandit,
        phone: '+919999999992',
      ),
      AppUser(
        id: 'a1',
        name: 'Admin',
        email: 'admin@saralpooja.app',
        role: UserRole.admin,
        phone: '+919999999993',
      ),
    ]);
    _currentUser = _users.first;
    _addresses.add(
      const Address(
        id: 'addr1',
        userId: 'u1',
        label: 'Home',
        line1: 'Flat 302, Shanti Residency, MG Road',
        city: 'Lucknow',
        state: 'UP',
        pincode: '226001',
        isDefault: true,
      ),
    );
    _pandits.addAll(const [
      PanditProfile(
        id: 'p1',
        name: 'Pt. Dev Mishra',
        specialties: ['Griha Pravesh', 'Kundli', 'Havan'],
        languages: ['Hindi', 'Sanskrit'],
        rating: 4.9,
        completedBookings: 284,
        chatPricePerMinute: 25,
      ),
      PanditProfile(
        id: 'p2',
        name: 'Pt. Om Tiwari',
        specialties: ['Satyanarayan', 'Marriage Muhurat'],
        languages: ['Hindi', 'English'],
        rating: 4.8,
        completedBookings: 151,
        chatPricePerMinute: 20,
      ),
    ]);
    _packages.addAll(const [
      CatalogueItem(
        id: 'pkg1',
        title: 'Griha Pravesh Pooja',
        description:
            'A complete house warming ceremony with sankalp, havan, and griha shanti rituals.',
        price: 5100,
        imageUrl: 'assets/images/image1.jpg',
        includedItems: [
          'Kalash sthapana',
          'Ganesh pujan',
          'Navgraha shanti',
          'Havan samagri',
        ],
        durationMinutes: 150,
        sortOrder: 1,
      ),
      CatalogueItem(
        id: 'pkg2',
        title: 'Satyanarayan Katha',
        description:
            'Traditional katha and prasad ceremony for family prosperity and gratitude.',
        price: 3100,
        imageUrl: 'assets/images/image2.jpg',
        includedItems: ['Katha path', 'Panchamrit', 'Aarti', 'Basic samigri'],
        durationMinutes: 120,
        sortOrder: 2,
      ),
    ]);
    _special.addAll(const [
      CatalogueItem(
        id: 'sp1',
        title: 'Mahamrityunjaya Jaap',
        description:
            'Online special pooja performed by allotted pandits with proof video after completion.',
        price: 11000,
        imageUrl: 'assets/images/image10.jpg',
        includedItems: ['Sankalp', 'Jaap', 'Havan', 'Proof video'],
        durationMinutes: 240,
      ),
    ]);
    _shop.addAll(const [
      CatalogueItem(
        id: 'sh1',
        title: 'Grah Pravesh Samigri Kit',
        description: 'Curated samigri kit for house warming rituals.',
        price: 1499,
        imageUrl: 'assets/images/image11.jpg',
        includedItems: ['Havan sticks', 'Ghee diya', 'Kalawa', 'Roli chawal'],
        stock: 24,
      ),
      CatalogueItem(
        id: 'sh2',
        title: 'Festival Pooja Thali',
        description: 'Premium pooja thali set for daily and festival worship.',
        price: 899,
        imageUrl: 'assets/images/image12.jpg',
        includedItems: ['Brass thali', 'Diya', 'Bell', 'Incense holder'],
        stock: 40,
      ),
    ]);
    _wallets['u1'] = 25000;
  }

  @override
  bool get isAuthenticated => _authenticated;

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
  List<AppNotification> get notifications => List.unmodifiable(
    _notifications.where(
      (n) => n.userId == _currentUser.id || _currentUser.role == UserRole.admin,
    ),
  );

  @override
  List<Address> addressesFor(String userId) => List.unmodifiable(
    _addresses.where((address) => address.userId == userId),
  );

  @override
  Wallet walletFor(String userId) =>
      Wallet(userId: userId, balance: _wallets[userId] ?? 0);

  @override
  List<WalletLedgerEntry> ledgerFor(String userId) =>
      List.unmodifiable(_ledger.where((e) => e.userId == userId));

  @override
  List<CartLine> cartFor(String userId) =>
      List.unmodifiable(_cart[userId] ?? const []);

  @override
  ChatSession? chatSessionById(String sessionId) => _sessions[sessionId];

  @override
  List<ChatMessage> messagesFor(String sessionId) =>
      List.unmodifiable(_messages[sessionId] ?? const []);

  @override
  List<ProofVideo> proofsFor(String userId, DateTime now) {
    return _proofs
        .where((p) {
          final owner = p.userId == userId;
          final admin = _currentUser.role == UserRole.admin;
          return (owner || admin) && p.isAvailable(now);
        })
        .toList(growable: false);
  }

  @override
  Stream<List<Booking>> bookingStream(String userId) {
    Future.microtask(() => _emitBookings());
    return _bookingController.stream.map((items) {
      if (_currentUser.role == UserRole.admin) return items;
      if (_currentUser.role == UserRole.pandit) {
        return items.where((b) => b.panditId == _currentUser.id).toList();
      }
      return items.where((b) => b.userId == userId).toList();
    });
  }

  @override
  Stream<List<ChatMessage>> chatStream(String sessionId) {
    final controller = _chatControllers.putIfAbsent(
      sessionId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    Future.microtask(() => controller.add(messagesFor(sessionId)));
    return controller.stream;
  }

  @override
  Future<AppUser> signInAs(UserRole role) async {
    _currentUser = _users.firstWhere((user) => user.role == role);
    _authenticated = true;
    _wallets.putIfAbsent(
      _currentUser.id,
      () => role == UserRole.user ? 25000 : 0,
    );
    _emitBookings();
    return _currentUser;
  }

  @override
  Future<void> reload() async {}

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final role = email.contains('admin')
        ? UserRole.admin
        : email.contains('pandit')
        ? UserRole.pandit
        : UserRole.user;
    return signInAs(role);
  }

  @override
  Future<AppUser> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final user = AppUser(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email,
      role: UserRole.user,
      phone: phone,
    );
    _users.add(user);
    _wallets[user.id] = 0;
    _currentUser = user;
    _authenticated = true;
    return user;
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
  }

  @override
  Future<Address> saveAddress(Address address) async {
    _requireUser();
    _addresses.removeWhere((item) => item.id == address.id);
    _addresses.add(address);
    return address;
  }

  @override
  Future<void> topUpWallet(String userId, int amount) async {
    final payment = await _paymentService.pay(
      userId: userId,
      amount: amount,
      method: PaymentMethod.razorpay,
      referenceId: 'wallet_topup',
    );
    _payments.add(payment);
    _credit(userId, amount, 'Wallet top-up', payment.id);
    _notify(
      userId,
      'Wallet top-up success',
      'Your wallet was credited with Rs $amount.',
    );
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
    _requireUser();
    final item = _catalogueForType(
      type,
    ).firstWhere((entry) => entry.id == catalogueId);
    if ((type == BookingType.offlinePandit ||
            type == BookingType.poojaPackage) &&
        address == null) {
      throw const AppException('A service address is required.');
    }
    final id = 'b_${DateTime.now().microsecondsSinceEpoch}';
    final paymentId = await _capturePayment(
      userId: _currentUser.id,
      amount: item.price,
      method: paymentMethod,
      referenceId: id,
      reason: 'Booking ${item.title}',
    );
    final booking = Booking(
      id: id,
      userId: _currentUser.id,
      type: type,
      title: item.title,
      amount: item.price,
      status: type == BookingType.specialPooja
          ? BookingStatus.processing
          : BookingStatus.pending,
      scheduledAt: scheduledAt,
      address: address,
      notes: notes,
      paymentId: paymentId,
      createdAt: DateTime.now(),
    );
    _bookings.add(booking);
    _statusHistory.add(
      StatusEntry(
        bookingId: id,
        status: booking.status,
        changedBy: _currentUser.id,
        createdAt: DateTime.now(),
        note: 'Created after payment',
      ),
    );
    _notify(
      _currentUser.id,
      'Booking confirmed',
      '${item.title} has been booked.',
    );
    _notify('a1', 'New booking', '${_currentUser.name} booked ${item.title}.');
    _emitBookings();
    return booking;
  }

  @override
  Future<Booking> adminUpdateBooking({
    required String bookingId,
    required BookingStatus status,
    String? panditId,
    String note = '',
  }) async {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index < 0) throw const AppException('Booking not found.');
    final existing = _bookings[index];
    final panditMayUpdate =
        _currentUser.role == UserRole.pandit &&
        existing.panditId == _currentUser.id &&
        panditId == null &&
        (status == BookingStatus.inProgress ||
            status == BookingStatus.completed);
    if (_currentUser.role != UserRole.admin && !panditMayUpdate) {
      throw const AppException('Admin access required.');
    }
    final booking = _bookings[index].copyWith(
      status: status,
      panditId: panditId,
      notes: note.isEmpty ? null : note,
    );
    _bookings[index] = booking;
    _statusHistory.add(
      StatusEntry(
        bookingId: bookingId,
        status: status,
        changedBy: _currentUser.id,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
    _notify(
      booking.userId,
      'Booking status updated',
      '${booking.title} is now ${status.name}.',
    );
    if (panditId != null) {
      _notify(
        panditId,
        'New assignment',
        '${booking.title} assigned near ${booking.panditSafeAddress}.',
      );
    }
    _emitBookings();
    return booking;
  }

  @override
  Future<ChatSession> bookChatSession({
    required String panditId,
    required int minutes,
    required PaymentMethod paymentMethod,
  }) async {
    _requireUser();
    final pandit = _pandits.firstWhere((profile) => profile.id == panditId);
    if (!pandit.isOnline) {
      throw const AppException('Selected pandit is offline.');
    }
    final amount = pandit.chatPricePerMinute * minutes;
    final id = 'chat_${DateTime.now().microsecondsSinceEpoch}';
    await _capturePayment(
      userId: _currentUser.id,
      amount: amount,
      method: paymentMethod,
      referenceId: id,
      reason: '$minutes minute astrology chat',
    );
    final now = DateTime.now();
    final session = ChatSession(
      id: id,
      userId: _currentUser.id,
      panditId: panditId,
      startedAt: now,
      endsAt: now.add(Duration(minutes: minutes)),
      price: amount,
    );
    _sessions[id] = session;
    _messages[id] = [
      ChatMessage(
        id: 'm_$id',
        sessionId: id,
        senderId: panditId,
        text:
            'Namaste. Please share your question and any image you want me to review.',
        createdAt: now,
      ),
    ];
    _notify(
      _currentUser.id,
      'Chat session started',
      'Your $minutes minute session is active.',
    );
    return session;
  }

  @override
  Future<ChatSession> extendChatSession({
    required String sessionId,
    required int minutes,
    required PaymentMethod paymentMethod,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) throw const AppException('Chat session not found.');
    final pandit = _pandits.firstWhere(
      (profile) => profile.id == session.panditId,
    );
    final amount = pandit.chatPricePerMinute * minutes;
    await _capturePayment(
      userId: session.userId,
      amount: amount,
      method: paymentMethod,
      referenceId: sessionId,
      reason: 'Chat extension',
    );
    final extended = session.copyWith(
      endsAt: session.endsAt.add(Duration(minutes: minutes)),
    );
    _sessions[sessionId] = extended;
    _notify(
      session.userId,
      'Session extended',
      'Your chat was extended by $minutes minutes.',
    );
    return extended;
  }

  @override
  Future<ChatMessage> sendChatMessage({
    required String sessionId,
    required String text,
    Uint8List? imageBytes,
  }) async {
    final session = _sessions[sessionId];
    if (session == null) throw const AppException('Chat session not found.');
    if (session.remaining(DateTime.now()) == Duration.zero) {
      _sessions[sessionId] = session.copyWith(status: BookingStatus.expired);
      throw const AppException('Chat session has expired.');
    }
    final isParticipant =
        _currentUser.id == session.userId ||
        _currentUser.id == session.panditId;
    if (!isParticipant && _currentUser.role != UserRole.admin) {
      throw const AppException('You cannot access this chat.');
    }
    String? imageUrl;
    if (imageBytes != null) {
      imageUrl = await _mediaStorage.uploadBytes(
        folder: 'chat/$sessionId',
        fileName: 'image_${DateTime.now().microsecondsSinceEpoch}.jpg',
        bytes: imageBytes,
        contentType: 'image/jpeg',
        maxBytes: 10 * 1024 * 1024,
      );
    }
    final message = ChatMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      sessionId: sessionId,
      senderId: _currentUser.id,
      text: text,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );
    _messages.putIfAbsent(sessionId, () => []).add(message);
    _chatControllers[sessionId]?.add(messagesFor(sessionId));
    if (session.isNearEnd(DateTime.now())) {
      _notify(
        session.userId,
        'Session is about to end',
        'Recharge or extend to continue your consultation.',
      );
    }
    return message;
  }

  @override
  Future<void> addToCart(String itemId, int quantity) async {
    _requireUser();
    if (quantity <= 0) {
      throw const AppException('Quantity must be at least one.');
    }
    final item = _shop.firstWhere((entry) => entry.id == itemId);
    final lines = _cart.putIfAbsent(_currentUser.id, () => []);
    final index = lines.indexWhere((line) => line.item.id == itemId);
    if (index >= 0) {
      lines[index] = lines[index].copyWith(
        quantity: lines[index].quantity + quantity,
      );
    } else {
      lines.add(CartLine(item: item, quantity: quantity));
    }
  }

  @override
  Future<void> updateCart(String itemId, int quantity) async {
    final lines = _cart.putIfAbsent(_currentUser.id, () => []);
    if (quantity <= 0) {
      lines.removeWhere((line) => line.item.id == itemId);
      return;
    }
    final index = lines.indexWhere((line) => line.item.id == itemId);
    if (index >= 0) lines[index] = lines[index].copyWith(quantity: quantity);
  }

  @override
  Future<ShopOrder> checkoutCart(PaymentMethod paymentMethod) async {
    _requireUser();
    final lines = List<CartLine>.from(_cart[_currentUser.id] ?? const []);
    if (lines.isEmpty) throw const AppException('Cart is empty.');
    final total = lines.fold<int>(0, (sum, line) => sum + line.total);
    final id = 'ord_${DateTime.now().microsecondsSinceEpoch}';
    await _capturePayment(
      userId: _currentUser.id,
      amount: total,
      method: paymentMethod,
      referenceId: id,
      reason: 'Shop order',
    );
    final order = ShopOrder(
      id: id,
      userId: _currentUser.id,
      lines: lines,
      total: total,
      status: 'confirmed',
      createdAt: DateTime.now(),
    );
    _orders.add(order);
    _cart[_currentUser.id] = [];
    _notify(
      _currentUser.id,
      'Order confirmed',
      'Your samigri order was placed.',
    );
    return order;
  }

  @override
  Future<CatalogueItem> upsertCatalogue({
    required String area,
    required CatalogueItem item,
  }) async {
    _requireAdmin();
    final list = _catalogueByArea(area);
    final index = list.indexWhere((entry) => entry.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.add(item);
    }
    return item;
  }

  @override
  Future<void> deleteCatalogue({
    required String area,
    required String id,
  }) async {
    _requireAdmin();
    _catalogueByArea(area).removeWhere((entry) => entry.id == id);
  }

  @override
  Future<ProofVideo> uploadProofVideo({
    required String bookingId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    _requireAdmin();
    final booking = _bookings.firstWhere((item) => item.id == bookingId);
    if (bytes.length > 300 * 1024 * 1024) {
      throw const AppException('Proof video must be 300 MB or smaller.');
    }
    final key = 'proofs/$bookingId/$fileName';
    final url = await _mediaStorage.uploadBytes(
      folder: 'proofs/$bookingId',
      fileName: fileName,
      bytes: bytes,
      contentType: 'video/mp4',
      maxBytes: 300 * 1024 * 1024,
    );
    final now = DateTime.now();
    final proof = ProofVideo(
      id: 'proof_${now.microsecondsSinceEpoch}',
      bookingId: bookingId,
      userId: booking.userId,
      mediaUrl: url,
      storageKey: key,
      uploadedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      sizeBytes: bytes.length,
    );
    _proofs.removeWhere((entry) => entry.bookingId == bookingId);
    _proofs.add(proof);
    _notify(
      booking.userId,
      'Proof video available',
      'Download your special pooja proof within 7 days.',
    );
    return proof;
  }

  List<CatalogueItem> _catalogueForType(BookingType type) {
    return switch (type) {
      BookingType.specialPooja => _special,
      BookingType.offlinePandit || BookingType.poojaPackage => _packages,
      BookingType.chat => _packages,
    };
  }

  List<CatalogueItem> _catalogueByArea(String area) {
    return switch (area) {
      'packages' => _packages,
      'special' => _special,
      'shop' => _shop,
      _ => throw const AppException('Unknown catalogue area.'),
    };
  }

  Future<String> _capturePayment({
    required String userId,
    required int amount,
    required PaymentMethod method,
    required String referenceId,
    required String reason,
  }) async {
    if (method == PaymentMethod.wallet) {
      _debit(userId, amount, reason, referenceId);
      return 'wallet_$referenceId';
    }
    final payment = await _paymentService.pay(
      userId: userId,
      amount: amount,
      method: method,
      referenceId: referenceId,
    );
    _payments.add(payment);
    return payment.id;
  }

  void _credit(String userId, int amount, String reason, String referenceId) {
    final balance = (_wallets[userId] ?? 0) + amount;
    _wallets[userId] = balance;
    _ledger.add(
      WalletLedgerEntry(
        id: 'led_${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        type: LedgerType.credit,
        amount: amount,
        balanceAfter: balance,
        reason: reason,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _debit(String userId, int amount, String reason, String referenceId) {
    final current = _wallets[userId] ?? 0;
    if (current < amount) {
      throw const AppException('Insufficient wallet balance.');
    }
    final balance = current - amount;
    _wallets[userId] = balance;
    _ledger.add(
      WalletLedgerEntry(
        id: 'led_${DateTime.now().microsecondsSinceEpoch}',
        userId: userId,
        type: LedgerType.debit,
        amount: amount,
        balanceAfter: balance,
        reason: reason,
        referenceId: referenceId,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _notify(String userId, String title, String body) {
    _notifications.add(
      AppNotification(
        id: 'nt_${DateTime.now().microsecondsSinceEpoch}_${_notifications.length}',
        userId: userId,
        title: title,
        body: body,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _emitBookings() => _bookingController.add(List.unmodifiable(_bookings));

  void _requireUser() {
    if (_currentUser.role != UserRole.user) {
      throw const AppException('This action is available to users only.');
    }
  }

  void _requireAdmin() {
    if (_currentUser.role != UserRole.admin) {
      throw const AppException('Admin access required.');
    }
  }
}
