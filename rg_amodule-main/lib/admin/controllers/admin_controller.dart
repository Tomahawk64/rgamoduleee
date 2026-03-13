// lib/admin/controllers/admin_controller.dart
//
// StateNotifier controller for the Admin Dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../booking/models/booking_status.dart';
import '../../core/constants/demo_config.dart';
import '../models/admin_models.dart';
import '../repository/admin_repository.dart';

class AdminController extends StateNotifier<AdminState> {
  AdminController(this._repo) : super(const AdminState()) {
    load();
  }

  final IAdminRepository _repo;

  // ── Full load ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.fetchPoojas(),
        _repo.fetchPandits(),
        _repo.fetchBookings(),
        _repo.fetchConsultations(),
        _repo.fetchReport(),
      ]);
      state = state.copyWith(
        poojas: results[0] as List<AdminPooja>,
        pandits: results[1] as List<AdminPandit>,
        bookings: results[2] as List<AdminBookingRow>,
        consultations: results[3] as List<AdminConsultationRow>,
        report: results[4] as AdminReport,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void clearError() => state = state.copyWith(error: null);

  // ── Poojas ────────────────────────────────────────────────────────────────

  Future<void> createPooja(AdminPooja pooja) async {
    _setSectionLoading(AdminSection.poojas, true);
    try {
      final created = await _repo.createPooja(pooja);
      state = state.copyWith(
        poojas: [...state.poojas, created],
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    }
  }

  Future<void> updatePooja(AdminPooja pooja) async {
    _setSectionLoading(AdminSection.poojas, true);
    try {
      final updated = await _repo.updatePooja(pooja);
      state = state.copyWith(
        poojas: state.poojas
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    }
  }

  Future<void> deletePooja(String id) async {
    if (DemoConfig.demoMode) {
      state = state.copyWith(error: 'Delete is disabled in demo mode.');
      return;
    }
    _setSectionLoading(AdminSection.poojas, true);
    try {
      await _repo.deletePooja(id);
      state = state.copyWith(
        poojas: state.poojas.where((p) => p.id != id).toList(),
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.poojas, false),
      );
    }
  }

  Future<void> togglePooja(String id, {required bool isActive}) async {
    try {
      final updated = await _repo.togglePooja(id, isActive: isActive);
      state = state.copyWith(
        poojas: state.poojas
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Pandits ───────────────────────────────────────────────────────────────

  Future<void> updatePandit(AdminPandit pandit) async {
    _setSectionLoading(AdminSection.pandits, true);
    try {
      final updated = await _repo.updatePandit(pandit);
      state = state.copyWith(
        pandits: state.pandits
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
        sectionLoading: _withSection(AdminSection.pandits, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.pandits, false),
      );
    }
  }

  Future<void> togglePandit(String id, {required bool isActive}) async {
    try {
      final updated =
          await _repo.togglePandit(id, isActive: isActive);
      state = state.copyWith(
        pandits: state.pandits
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleConsultation(String id,
      {required bool enabled}) async {
    try {
      final updated =
          await _repo.toggleConsultation(id, enabled: enabled);
      state = state.copyWith(
        pandits: state.pandits
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateConsultationRates(
      String id, List<AdminRate> rates) async {
    try {
      final updated =
          await _repo.updateConsultationRates(id, rates);
      state = state.copyWith(
        pandits: state.pandits
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Bookings ──────────────────────────────────────────────────────────────

  Future<void> updateBookingStatus(String id, BookingStatus status) async {
    try {
      final updated = await _repo.updateBookingStatus(id, status);
      state = state.copyWith(
        bookings: state.bookings
            .map((b) => b.id == updated.id ? updated : b)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> assignPandit(String bookingId, String panditId) async {
    try {
      final updated = await _repo.assignPandit(bookingId, panditId);
      state = state.copyWith(
        bookings: state.bookings
            .map((b) => b.id == updated.id ? updated : b)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<void> loadUsers() async {
    _setSectionLoading(AdminSection.users, true);
    try {
      final users = await _repo.fetchUsers();
      state = state.copyWith(
        users: users,
        sectionLoading: _withSection(AdminSection.users, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.users, false),
      );
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    try {
      final updated = await _repo.updateUserRole(userId, role);
      state = state.copyWith(
        users: state.users
            .map((u) => u.id == updated.id ? updated : u)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleUser(String userId, {required bool isActive}) async {
    try {
      final updated = await _repo.toggleUser(userId, isActive: isActive);
      state = state.copyWith(
        users: state.users
            .map((u) => u.id == updated.id ? updated : u)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<void> loadProducts() async {
    _setSectionLoading(AdminSection.products, true);
    try {
      final products = await _repo.fetchProducts();
      state = state.copyWith(
        products: products,
        sectionLoading: _withSection(AdminSection.products, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    }
  }

  Future<void> createProduct(AdminProduct product) async {
    _setSectionLoading(AdminSection.products, true);
    try {
      final created = await _repo.createProduct(product);
      state = state.copyWith(
        products: [...state.products, created],
        sectionLoading: _withSection(AdminSection.products, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    }
  }

  Future<void> updateProduct(AdminProduct product) async {
    _setSectionLoading(AdminSection.products, true);
    try {
      final updated = await _repo.updateProduct(product);
      state = state.copyWith(
        products: state.products
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    }
  }

  Future<void> deleteProduct(String id) async {
    if (DemoConfig.demoMode) {
      state = state.copyWith(error: 'Delete is disabled in demo mode.');
      return;
    }
    _setSectionLoading(AdminSection.products, true);
    try {
      await _repo.deleteProduct(id);
      state = state.copyWith(
        products: state.products.where((p) => p.id != id).toList(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        sectionLoading: _withSection(AdminSection.products, false),
      );
    }
  }

  Future<void> toggleProduct(String id, {required bool isActive}) async {
    try {
      final updated = await _repo.toggleProduct(id, isActive: isActive);
      state = state.copyWith(
        products: state.products
            .map((p) => p.id == updated.id ? updated : p)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }


  // ── Consultations ─────────────────────────────────────────────────────────

  Future<void> endSession(String id) async {
    if (DemoConfig.demoMode) {
      state = state.copyWith(
          error: 'End session is disabled in demo mode.');
      return;
    }
    try {
      await _repo.endSession(id);
      final refreshed = await _repo.fetchConsultations();
      state = state.copyWith(consultations: refreshed);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> refundOverride(String id) async {
    if (DemoConfig.demoMode) {
      state = state.copyWith(
          error: 'Refund override is disabled in demo mode.');
      return;
    }
    try {
      final updated = await _repo.refundOverride(id);
      state = state.copyWith(
        consultations: state.consultations
            .map((c) => c.id == updated.id ? updated : c)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setSectionLoading(AdminSection s, bool loading) {
    state = state.copyWith(
      sectionLoading: _withSection(s, loading),
    );
  }

  Map<AdminSection, bool> _withSection(AdminSection s, bool v) {
    return {...state.sectionLoading, s: v};
  }

  // ── Derived queries ───────────────────────────────────────────────────────

  List<AdminBookingRow> bookingsByStatus(BookingStatus? status) {
    if (status == null) return state.bookings;
    return state.bookings.where((b) => b.status == status).toList();
  }

  List<AdminConsultationRow> consultationsByStatus(
      AdminSessionStatus? status) {
    if (status == null) return state.consultations;
    return state.consultations.where((c) => c.status == status).toList();
  }
}
