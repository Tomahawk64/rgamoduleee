// lib/admin/repository/mock_admin_repository.dart
//
// In-memory mock implementation of [IAdminRepository] for demo mode.

import '../../booking/models/booking_status.dart';
import '../models/admin_models.dart';
import 'admin_repository.dart';

class MockAdminRepository implements IAdminRepository {
  final List<AdminPooja> _poojas = List.of(_seedPoojas);
  final List<AdminPandit> _pandits = List.of(_seedPandits);
  final List<AdminBookingRow> _bookings = List.of(_seedBookings);
  final List<AdminConsultationRow> _consultations = List.of(_seedConsultations);

  // ── Poojas ──────────────────────────────────────────────────────────────────
  @override
  Future<List<AdminPooja>> fetchPoojas() async {
    await _delay();
    return List.unmodifiable(_poojas);
  }

  @override
  Future<AdminPooja> createPooja(AdminPooja pooja) async {
    await _delay();
    _poojas.add(pooja);
    return pooja;
  }

  @override
  Future<AdminPooja> updatePooja(AdminPooja pooja) async {
    await _delay();
    final idx = _poojas.indexWhere((p) => p.id == pooja.id);
    if (idx != -1) _poojas[idx] = pooja;
    return pooja;
  }

  @override
  Future<void> deletePooja(String id) async {
    await _delay();
    _poojas.removeWhere((p) => p.id == id);
  }

  @override
  Future<AdminPooja> togglePooja(String id, {required bool isActive}) async {
    await _delay();
    final idx = _poojas.indexWhere((p) => p.id == id);
    if (idx != -1) _poojas[idx] = _poojas[idx].copyWith(isActive: isActive);
    return _poojas[idx];
  }

  // ── Pandits ─────────────────────────────────────────────────────────────────
  @override
  Future<List<AdminPandit>> fetchPandits() async {
    await _delay();
    return List.unmodifiable(_pandits);
  }

  @override
  Future<AdminPandit> updatePandit(AdminPandit pandit) async {
    await _delay();
    final idx = _pandits.indexWhere((p) => p.id == pandit.id);
    if (idx != -1) _pandits[idx] = pandit;
    return pandit;
  }

  @override
  Future<AdminPandit> togglePandit(String id, {required bool isActive}) async {
    await _delay();
    final idx = _pandits.indexWhere((p) => p.id == id);
    if (idx != -1) _pandits[idx] = _pandits[idx].copyWith(isActive: isActive);
    return _pandits[idx];
  }

  @override
  Future<AdminPandit> toggleConsultation(String id,
      {required bool enabled}) async {
    await _delay();
    final idx = _pandits.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _pandits[idx] = _pandits[idx].copyWith(consultationEnabled: enabled);
    }
    return _pandits[idx];
  }

  @override
  Future<AdminPandit> updateConsultationRates(
      String id, List<AdminRate> rates) async {
    await _delay();
    final idx = _pandits.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _pandits[idx] = _pandits[idx].copyWith(consultationRates: rates);
    }
    return _pandits[idx];
  }

  // ── Bookings ────────────────────────────────────────────────────────────────
  @override
  Future<List<AdminBookingRow>> fetchBookings() async {
    await _delay();
    return List.unmodifiable(_bookings);
  }

  @override
  Future<AdminBookingRow> updateBookingStatus(
      String id, BookingStatus status) async {
    await _delay();
    final idx = _bookings.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(status: status);
    }
    return _bookings[idx];
  }

  // ── Consultations ───────────────────────────────────────────────────────────
  @override
  Future<List<AdminConsultationRow>> fetchConsultations() async {
    await _delay();
    return List.unmodifiable(_consultations);
  }

  @override
  Future<void> endSession(String id) async {
    await _delay();
    final idx = _consultations.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _consultations[idx] = AdminConsultationRow(
        id: _consultations[idx].id,
        panditName: _consultations[idx].panditName,
        clientName: _consultations[idx].clientName,
        status: AdminSessionStatus.ended,
        durationMinutes: _consultations[idx].durationMinutes,
        amountPaise: _consultations[idx].amountPaise,
        startedAt: _consultations[idx].startedAt,
      );
    }
  }

  @override
  Future<AdminConsultationRow> refundOverride(String id) async {
    await _delay();
    final idx = _consultations.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _consultations[idx] = AdminConsultationRow(
        id: _consultations[idx].id,
        panditName: _consultations[idx].panditName,
        clientName: _consultations[idx].clientName,
        status: AdminSessionStatus.refunded,
        durationMinutes: _consultations[idx].durationMinutes,
        amountPaise: _consultations[idx].amountPaise,
        startedAt: _consultations[idx].startedAt,
      );
    }
    return _consultations[idx];
  }

  // ── Reports ─────────────────────────────────────────────────────────────────
  @override
  Future<AdminReport> fetchReport() async {
    await _delay();
    return _seedReport;
  }

  // ── Assign Pandit ────────────────────────────────────────────────────────────
  @override
  Future<AdminBookingRow> assignPandit(
      String bookingId, String panditId) async {
    await _delay();
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      final pandit =
          _pandits.firstWhere((p) => p.id == panditId, orElse: () => _pandits.first);
      _bookings[idx] = _bookings[idx].copyWith(
        panditName: pandit.name,
        panditId: panditId,
        status: _bookings[idx].status == BookingStatus.pending
            ? BookingStatus.confirmed
            : _bookings[idx].status,
      );
      return _bookings[idx];
    }
    throw Exception('Booking not found');
  }

  // ── Mark as Paid ────────────────────────────────────────────────────────────
  @override
  Future<AdminBookingRow> markAsPaid(String bookingId) async {
    await _delay();
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx != -1) {
      _bookings[idx] = _bookings[idx].copyWith(isPaid: true);
      return _bookings[idx];
    }
    throw Exception('Booking not found');
  }

  // ── Users ─────────────────────────────────────────────────────────────────────
  @override
  Future<List<AdminUser>> fetchUsers() async {
    await _delay();
    return [
      AdminUser(
        id: 'mock-user-1',
        fullName: 'Priya Sharma',
        role: 'user',
        isActive: true,
        createdAt: _epoch,
        email: 'priya@example.com',
        phone: '+91 98765 43210',
      ),
      AdminUser(
        id: 'mock-user-2',
        fullName: 'Arun Iyer',
        role: 'pandit',
        isActive: true,
        createdAt: _epoch,
        email: 'arun@example.com',
      ),
    ];
  }

  @override
  Future<AdminUser> updateUserRole(String userId, String role) async {
    await _delay();
    return AdminUser(
      id: userId,
      fullName: 'Mock User',
      role: role,
      isActive: true,
      createdAt: _epoch,
    );
  }

  @override
  Future<AdminUser> toggleUser(String userId, {required bool isActive}) async {
    await _delay();
    return AdminUser(
      id: userId,
      fullName: 'Mock User',
      role: 'user',
      isActive: isActive,
      createdAt: _epoch,
    );
  }

  // ── Products ──────────────────────────────────────────────────────────────────
  final List<AdminProduct> _products = [];

  @override
  Future<List<AdminProduct>> fetchProducts() async {
    await _delay();
    return List.unmodifiable(_products);
  }

  @override
  Future<AdminProduct> createProduct(AdminProduct product) async {
    await _delay();
    final p = AdminProduct(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      name: product.name,
      description: product.description,
      pricePaise: product.pricePaise,
      category: product.category,
      stock: product.stock,
      isActive: product.isActive,
      isBestSeller: product.isBestSeller,
      createdAt: DateTime.now(),
      imageUrl: product.imageUrl,
      includes: product.includes,
    );
    _products.add(p);
    return p;
  }

  @override
  Future<AdminProduct> updateProduct(AdminProduct product) async {
    await _delay();
    final idx = _products.indexWhere((p) => p.id == product.id);
    if (idx != -1) _products[idx] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _delay();
    _products.removeWhere((p) => p.id == id);
  }

  @override
  Future<AdminProduct> toggleProduct(String id,
      {required bool isActive}) async {
    await _delay();
    final idx = _products.indexWhere((p) => p.id == id);
    if (idx != -1) {
      _products[idx] = _products[idx].copyWith(isActive: isActive);
      return _products[idx];
    }
    throw Exception('Product not found');
  }

  // ── Helper ──────────────────────────────────────────────────────────────────
  static Future<void> _delay() =>
      Future.delayed(const Duration(milliseconds: 300));
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

// ══════════════════════════════════════════════════════════════════════════════
// SEED DATA
// ══════════════════════════════════════════════════════════════════════════════

final _now = DateTime.now();

final List<AdminPooja> _seedPoojas = [
  AdminPooja(
    id: 'bbbb0001-0001-4001-8001-000000000001',
    title: 'Kamakhya Devi Pooja',
    category: 'special',
    description: 'Sacred Kamakhya Devi Pooja performed at the Kamakhya Temple.',
    imageUrl: 'assets/images/image5.jpg',
    basePrice: 5999,
    durationMinutes: 120,
    isActive: true,
    isOnlineAvailable: false,
    tags: ['Shakti Peetha', 'Fertility', 'Marriage'],
    createdAt: _now.subtract(const Duration(days: 60)),
  ),
  AdminPooja(
    id: 'bbbb0002-0002-4002-8002-000000000002',
    title: 'Mahamrityunjaya Jaap',
    category: 'special',
    description: '1,25,000 Mahamrityunjaya mantra jaap by 5 Vedic Brahmins.',
    imageUrl: 'assets/images/image6.jpg',
    basePrice: 11999,
    durationMinutes: 240,
    isActive: true,
    isOnlineAvailable: true,
    tags: ['Health', 'Protection', 'Shiva'],
    createdAt: _now.subtract(const Duration(days: 45)),
  ),
  AdminPooja(
    id: 'bbbb0003-0003-4003-8003-000000000003',
    title: 'Kaal Sarp Dosh Nivaran',
    category: 'special',
    description: 'Complete Kaal Sarp Dosh Nivaran Puja at Trimbakeshwar.',
    imageUrl: 'assets/images/image7.jpg',
    basePrice: 8999,
    durationMinutes: 180,
    isActive: true,
    isOnlineAvailable: false,
    tags: ['Dosh Nivaran', 'Career', 'Health'],
    createdAt: _now.subtract(const Duration(days: 30)),
  ),
];

final List<AdminPandit> _seedPandits = [
  AdminPandit(
    id: '22222222-2222-4222-8222-222222222222',
    name: 'Pandit Shivendra Shastri',
    specialties: ['Vedic Rituals', 'Astrology', 'Vastu', 'Navagraha Shanti'],
    languages: ['Hindi', 'Sanskrit', 'English'],
    rating: 4.8,
    totalBookings: 234,
    totalSessions: 89,
    isActive: true,
    consultationEnabled: true,
    consultationRates: const [
      AdminRate(durationMinutes: 10, pricePaise: 9900),
      AdminRate(durationMinutes: 15, pricePaise: 14900),
      AdminRate(durationMinutes: 30, pricePaise: 24900),
      AdminRate(durationMinutes: 60, pricePaise: 44900),
    ],
    yearsExperience: 15,
    joinedAt: _now.subtract(const Duration(days: 365)),
    email: 'demo_pandit@saralpooja.com',
    phone: '+919988776655',
  ),
  AdminPandit(
    id: 'p002',
    name: 'Acharya Deepak Joshi',
    specialties: ['Kundali', 'Muhurat', 'Remedies'],
    languages: ['Hindi', 'English'],
    rating: 4.6,
    totalBookings: 156,
    totalSessions: 67,
    isActive: true,
    consultationEnabled: true,
    consultationRates: const [
      AdminRate(durationMinutes: 15, pricePaise: 19900),
      AdminRate(durationMinutes: 30, pricePaise: 34900),
    ],
    yearsExperience: 12,
    joinedAt: _now.subtract(const Duration(days: 300)),
    email: 'deepak.joshi@example.com',
    phone: '+919876000001',
  ),
  AdminPandit(
    id: 'p003',
    name: 'Pandit Suresh Tiwari',
    specialties: ['Grih Pravesh', 'Marriage', 'Vastu'],
    languages: ['Hindi', 'Sanskrit'],
    rating: 4.9,
    totalBookings: 312,
    totalSessions: 45,
    isActive: true,
    consultationEnabled: false,
    consultationRates: const [],
    yearsExperience: 20,
    joinedAt: _now.subtract(const Duration(days: 500)),
    email: 'suresh.tiwari@example.com',
    phone: '+919876000002',
  ),
];

final List<AdminBookingRow> _seedBookings = [
  AdminBookingRow(
    id: 'dddd0001-0001-4001-8001-000000000001',
    packageTitle: 'Satyanarayan Katha',
    clientName: 'Rajesh Kumar',
    panditName: 'Pt. Shivendra Shastri',
    status: BookingStatus.confirmed,
    amount: 1999,
    isPaid: true,
    isOnline: false,
    scheduledAt: _now.add(const Duration(days: 7)),
    clientPhone: '+91 98765 43211',
    clientEmail: 'rajesh.kumar@example.com',
    timeSlot: '10:00 AM – 12:00 PM',
    address: '12, Shanti Nagar, Bhopal, MP – 462001',
  ),
  AdminBookingRow(
    id: 'dddd0002-0002-4002-8002-000000000002',
    packageTitle: 'Rudrabhishek',
    clientName: 'Rajesh Kumar',
    panditName: 'Pt. Shivendra Shastri',
    status: BookingStatus.completed,
    amount: 1499,
    isPaid: true,
    isOnline: true,
    specialPoojaId: 'bbbb0002-0002-4002-8002-000000000002',
    scheduledAt: _now.subtract(const Duration(days: 5)),
    clientPhone: '+91 98765 43211',
    clientEmail: 'rajesh.kumar@example.com',
    timeSlot: '9:00 AM – 10:30 AM',
    address: 'Online (Zoom)',
  ),
  AdminBookingRow(
    id: 'dddd0003-0003-4003-8003-000000000003',
    packageTitle: 'Grih Pravesh Pooja',
    clientName: 'Rajesh Kumar',
    panditName: 'Pt. Shivendra Shastri',
    status: BookingStatus.assigned,
    amount: 3499,
    isPaid: true,
    isOnline: false,
    scheduledAt: _now.add(const Duration(days: 3)),
    clientPhone: '+91 98765 43211',
    clientEmail: 'rajesh.kumar@example.com',
    timeSlot: '8:00 AM – 11:00 AM',
    address: 'Plot 45, Arera Colony, Bhopal, MP – 462016',
  ),
  AdminBookingRow(
    id: 'bk_demo_004',
    packageTitle: 'Sunderkand Path',
    clientName: 'Priya Sharma',
    panditName: null,
    status: BookingStatus.pending,
    amount: 799,
    isPaid: false,
    isOnline: true,
    scheduledAt: _now.add(const Duration(days: 10)),
    clientPhone: '+91 87654 32109',
    clientEmail: 'priya.sharma@example.com',
    timeSlot: '7:00 AM – 8:30 AM',
    address: 'Online (Google Meet)',
    userNotes: 'Please arrange for Prasad delivery if possible.',
  ),
  AdminBookingRow(
    id: 'bk_demo_005',
    packageTitle: 'Ganesh Chaturthi Puja',
    clientName: 'Amit Patel',
    panditName: 'Pt. Suresh Tiwari',
    status: BookingStatus.confirmed,
    amount: 1499,
    isPaid: true,
    isOnline: false,
    scheduledAt: _now.add(const Duration(days: 14)),
    clientPhone: '+91 76543 21098',
    clientEmail: 'amit.patel@example.com',
    timeSlot: '11:00 AM – 1:00 PM',
    address: 'B-7, Vastrapur, Ahmedabad, GJ – 380015',
  ),
  AdminBookingRow(
    id: 'bk_demo_006',
    packageTitle: 'Navgraha Shanti Puja',
    clientName: 'Sunita Rao',
    panditName: null,
    status: BookingStatus.pending,
    amount: 2499,
    isPaid: false,
    isOnline: false,
    scheduledAt: _now.add(const Duration(days: 5)),
    clientPhone: '+91 99887 76655',
    clientEmail: 'sunita.rao@example.com',
    timeSlot: '6:00 AM – 8:00 AM',
    address: '101, Srinivasa Nagar, Hyderabad, TS – 500038',
    userNotes: 'Husband will also be present. Two people total.',
  ),
];

final List<AdminConsultationRow> _seedConsultations = [
  AdminConsultationRow(
    id: 'eeee0001-0001-4001-8001-000000000001',
    panditName: 'Pt. Shivendra Shastri',
    clientName: 'Rajesh Kumar',
    status: AdminSessionStatus.ended,
    durationMinutes: 30,
    amountPaise: 24900,
    startedAt: _now.subtract(const Duration(days: 10)),
  ),
  AdminConsultationRow(
    id: 'eeee0002-0002-4002-8002-000000000002',
    panditName: 'Pt. Shivendra Shastri',
    clientName: 'Rajesh Kumar',
    status: AdminSessionStatus.expired,
    durationMinutes: 15,
    amountPaise: 14900,
    startedAt: _now.subtract(const Duration(days: 3)),
  ),
  AdminConsultationRow(
    id: 'consult_demo_003',
    panditName: 'Acharya Deepak Joshi',
    clientName: 'Priya Sharma',
    status: AdminSessionStatus.ended,
    durationMinutes: 30,
    amountPaise: 34900,
    startedAt: _now.subtract(const Duration(days: 7)),
  ),
  AdminConsultationRow(
    id: 'consult_demo_004',
    panditName: 'Pt. Shivendra Shastri',
    clientName: 'Amit Patel',
    status: AdminSessionStatus.active,
    durationMinutes: 15,
    amountPaise: 14900,
    startedAt: _now.subtract(const Duration(minutes: 5)),
  ),
];

const AdminReport _seedReport = AdminReport(
  totalBookings: 523,
  monthlyBookings: 47,
  totalConsultations: 201,
  monthlyConsultations: 18,
  monthlyRevenuePaise: 23500000, // ₹2.35L
  totalRevenuePaise: 185000000, // ₹18.5L
  activeUsers: 312,
  totalUsers: 1247,
  activePandits: 8,
  topPandits: [
    TopPandit(
      name: 'Pt. Shivendra Shastri',
      bookings: 234,
      revenuePaise: 45000000,
      rating: 4.8,
    ),
    TopPandit(
      name: 'Acharya Deepak Joshi',
      bookings: 156,
      revenuePaise: 32000000,
      rating: 4.6,
    ),
    TopPandit(
      name: 'Pt. Suresh Tiwari',
      bookings: 312,
      revenuePaise: 58000000,
      rating: 4.9,
    ),
  ],
  revenueHistory: [
    MonthlyPoint(month: 'Sep', revenuePaise: 18500000, bookings: 35),
    MonthlyPoint(month: 'Oct', revenuePaise: 21000000, bookings: 41),
    MonthlyPoint(month: 'Nov', revenuePaise: 19800000, bookings: 38),
    MonthlyPoint(month: 'Dec', revenuePaise: 25000000, bookings: 52),
    MonthlyPoint(month: 'Jan', revenuePaise: 22500000, bookings: 44),
    MonthlyPoint(month: 'Feb', revenuePaise: 23500000, bookings: 47),
  ],
);
