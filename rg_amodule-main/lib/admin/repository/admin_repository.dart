// lib/admin/repository/admin_repository.dart
//
// Repository interface + in-memory mock implementation for the Admin module.

import 'dart:async';
import '../../booking/models/booking_status.dart';
import '../models/admin_models.dart';

// â”€â”€ Abstract interface â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

abstract class IAdminRepository {
  // Poojas
  Future<List<AdminPooja>> fetchPoojas();
  Future<AdminPooja> createPooja(AdminPooja pooja);
  Future<AdminPooja> updatePooja(AdminPooja pooja);
  Future<void> deletePooja(String id);
  Future<AdminPooja> togglePooja(String id, {required bool isActive});

  // Pandits
  Future<List<AdminPandit>> fetchPandits();
  Future<AdminPandit> updatePandit(AdminPandit pandit);
  Future<AdminPandit> togglePandit(String id, {required bool isActive});
  Future<AdminPandit> toggleConsultation(
      String id, {required bool enabled});
  Future<AdminPandit> updateConsultationRates(
      String id, List<AdminRate> rates);

  // Bookings
  Future<List<AdminBookingRow>> fetchBookings();
  Future<AdminBookingRow> updateBookingStatus(
      String id, BookingStatus status);
  Future<AdminBookingRow> assignPandit(String bookingId, String panditId);

  // Consultations
  Future<List<AdminConsultationRow>> fetchConsultations();
  Future<void> endSession(String id);
  Future<AdminConsultationRow> refundOverride(String id);

  // Users
  Future<List<AdminUser>> fetchUsers();
  Future<AdminUser> updateUserRole(String userId, String role);
  Future<AdminUser> toggleUser(String userId, {required bool isActive});

  // Products
  Future<List<AdminProduct>> fetchProducts();
  Future<AdminProduct> createProduct(AdminProduct product);
  Future<AdminProduct> updateProduct(AdminProduct product);
  Future<void> deleteProduct(String id);
  Future<AdminProduct> toggleProduct(String id, {required bool isActive});

  // Reports
  Future<AdminReport> fetchReport();
}
