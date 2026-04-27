// lib/payment/services/order_service.dart
// Orchestrates the cart-to-payment-to-admin flow

import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents an order created from cart
class Order {
  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotalPaise,
    required this.taxPaise,
    required this.totalPaise,
    required this.status,
    required this.paymentStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.paymentError,
  });

  final String id;
  final String userId;
  final List<Map<String, dynamic>> items;
  final int subtotalPaise;
  final int taxPaise;
  final int totalPaise;
  final String status;
  final String paymentStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? paymentError;

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      items: (json['items'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [],
      subtotalPaise: json['subtotal_paise'] as int,
      taxPaise: json['tax_paise'] as int,
      totalPaise: json['total_paise'] as int,
      status: json['status'] as String? ?? 'pending',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      paymentError: json['payment_error_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'items': items,
        'subtotal_paise': subtotalPaise,
        'tax_paise': taxPaise,
        'total_paise': totalPaise,
        'status': status,
        'payment_status': paymentStatus,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'payment_error_message': paymentError,
      };
}

/// Service for managing order lifecycle and payments
abstract class IOrderService {
  /// Fetch order by ID
  Future<Order?> getOrder(String orderId);

  /// Get pending orders for user
  Future<List<Order>> getPendingOrders(String userId);

  /// Create payment reminder for pending payment
  Future<void> createPaymentReminder(
    String orderId,
    int amountDuePaise,
  );

  /// Send payment reminder notification to user
  Future<void> sendPaymentReminder(String orderId, String userId);

  /// Update order payment status (admin only)
  Future<void> updateOrderPaymentStatus(
    String orderId,
    String paymentStatus,
  );

  /// Get orders for admin dashboard
  Future<List<Order>> getOrdersForAdmin({
    String? statusFilter,
    String? paymentStatusFilter,
    int limit = 50,
  });
}

/// Supabase implementation of order service
class SupabaseOrderService implements IOrderService {
  SupabaseOrderService(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<Order?> getOrder(String orderId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (response == null) return null;
      return Order.fromJson(response);
    } catch (e) {
      print('Error fetching order: $e');
      return null;
    }
  }

  @override
  Future<List<Order>> getPendingOrders(String userId) async {
    try {
      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .eq('payment_status', 'pending')
          .order('created_at', ascending: false);

      return (response as List<dynamic>)
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching pending orders: $e');
      return [];
    }
  }

  @override
  Future<void> createPaymentReminder(
    String orderId,
    int amountDuePaise,
  ) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) throw Exception('Order not found');

      // Check if reminder already exists
      final existing = await _supabase
          .from('payment_reminders')
          .select()
          .eq('order_id', orderId)
          .eq('is_resolved', false)
          .maybeSingle();

      if (existing != null) {
        // Update existing reminder
        await _supabase
            .from('payment_reminders')
            .update({
              'reminder_count': (existing['reminder_count'] ?? 0) + 1,
              'next_reminder_at':
                  DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
            })
            .eq('id', existing['id']);
      } else {
        // Create new reminder
        await _supabase.from('payment_reminders').insert({
          'user_id': order.userId,
          'order_id': orderId,
          'transaction_type': 'order',
          'amount_due_paise': amountDuePaise,
          'reminder_count': 1,
          'next_reminder_at':
              DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          'is_resolved': false,
        });
      }
    } catch (e) {
      print('Error creating payment reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendPaymentReminder(String orderId, String userId) async {
    try {
      final order = await getOrder(orderId);
      if (order == null) throw Exception('Order not found');

      // Create notification for user
      await _supabase.from('notifications').insert({
        'user_id': userId,
        'type': 'payment_reminder',
        'title': 'Complete Your Payment',
        'message':
            'Your order of ₹${(order.totalPaise / 100).toStringAsFixed(2)} is pending payment. Complete it now to confirm your booking.',
        'data': {
          'order_id': orderId,
          'amount_paise': order.totalPaise,
        },
      });

      // Update reminder count safely
      final existing = await _supabase
          .from('payment_reminders')
          .select('id, reminder_count')
          .eq('order_id', orderId)
          .eq('is_resolved', false)
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('payment_reminders')
            .update({
              'reminder_count': (existing['reminder_count'] ?? 0) + 1,
              'last_reminder_sent': DateTime.now().toIso8601String(),
              'next_reminder_at':
                  DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
            })
            .eq('id', existing['id']);
      }
    } catch (e) {
      print('Error sending payment reminder: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateOrderPaymentStatus(
    String orderId,
    String paymentStatus,
  ) async {
    try {
      // Check if user is admin (this should be enforced via RLS)
      await _supabase
          .from('orders')
          .update({
            'payment_status': paymentStatus,
            'status': paymentStatus == 'completed' ? 'confirmed' : 'pending',
          })
          .eq('id', orderId);

      // Resolve payment reminder if payment is completed
      if (paymentStatus == 'completed') {
        await _supabase
            .from('payment_reminders')
            .update({'is_resolved': true})
            .eq('order_id', orderId)
            .eq('is_resolved', false);

        // Notify user that payment is confirmed
        final order = await getOrder(orderId);
        if (order != null) {
          await _supabase.from('notifications').insert({
            'user_id': order.userId,
            'type': 'payment_confirmed',
            'title': 'Payment Confirmed',
            'message':
                'Your payment of ₹${(order.totalPaise / 100).toStringAsFixed(2)} has been confirmed. Your booking is confirmed.',
            'data': {
              'order_id': orderId,
              'amount_paise': order.totalPaise,
            },
          });
        }
      }
    } catch (e) {
      print('Error updating payment status: $e');
      rethrow;
    }
  }

  @override
  Future<List<Order>> getOrdersForAdmin({
    String? statusFilter,
    String? paymentStatusFilter,
    int limit = 50,
  }) async {
    try {
      dynamic query = _supabase.from('orders').select();

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      if (paymentStatusFilter != null) {
        query = query.eq('payment_status', paymentStatusFilter);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List<dynamic>)
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching orders for admin: $e');
      return [];
    }
  }
}
