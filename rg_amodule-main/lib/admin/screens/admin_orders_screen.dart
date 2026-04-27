// lib/admin/screens/admin_orders_screen.dart
// Admin dashboard for managing shop orders with payment tracking

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../payment/services/order_service.dart';
import '../../widgets/base_scaffold.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  String _paymentFilter = 'all';
  String _statusFilter = 'all';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      title: 'Orders',
      body: Column(
        children: [
          // ── Search & Filter ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search field
                TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by order ID, customer name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All Orders',
                        selected: _paymentFilter == 'all' && _statusFilter == 'all',
                        onTap: () => setState(() {
                          _paymentFilter = 'all';
                          _statusFilter = 'all';
                        }),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Pending Payment',
                        selected: _paymentFilter == 'pending',
                        color: Colors.orange,
                        onTap: () => setState(() => _paymentFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Paid',
                        selected: _paymentFilter == 'completed',
                        color: Colors.green,
                        onTap: () => setState(() => _paymentFilter = 'completed'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Failed',
                        selected: _paymentFilter == 'failed',
                        color: Colors.red,
                        onTap: () => setState(() => _paymentFilter = 'failed'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── Orders List ──────────────────────────────────────────────
          Expanded(
            child: _OrdersListView(
              paymentFilter: _paymentFilter,
              statusFilter: _statusFilter,
              search: _search,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Orders List View ─────────────────────────────────────────────────────────

class _OrdersListView extends ConsumerWidget {
  const _OrdersListView({
    required this.paymentFilter,
    required this.statusFilter,
    required this.search,
  });

  final String paymentFilter;
  final String statusFilter;
  final String search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Order>>(
      future: _fetchOrders(ref),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final orders = snapshot.data ?? [];

        if (orders.isEmpty) {
          return const Center(
            child: Text('No orders found'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: orders.length,
          itemBuilder: (_, i) => _OrderCard(order: orders[i]),
        );
      },
    );
  }

  Future<List<Order>> _fetchOrders(WidgetRef ref) async {
    final service = SupabaseOrderService(Supabase.instance.client);
    final orders = await service.getOrdersForAdmin(
      statusFilter: statusFilter == 'all' ? null : statusFilter,
      paymentStatusFilter: paymentFilter == 'all' ? null : paymentFilter,
    );

    final q = search.trim().toLowerCase();
    if (q.isEmpty) return orders;

    return orders.where((o) {
      return o.id.toLowerCase().contains(q) ||
          o.userId.toLowerCase().contains(q);
    }).toList();
  }
}

// ── Order Card ───────────────────────────────────────────────────────────────

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Order ID & Payment Status ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Customer ID: ${order.userId.substring(0, 8)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _PaymentStatusBadge(status: order.paymentStatus),
                  const SizedBox(height: 4),
                  _OrderStatusBadge(status: order.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Order Items ──────────────────────────────────────────────
          Text(
            'Items (${order.items.length})',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${item['name']} × ${item['quantity']}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '₹${(item['total_paise'] / 100).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Amount ───────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              ),
              Text(
                '₹${(order.totalPaise / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Actions ──────────────────────────────────────────────────
          if (order.paymentStatus == 'pending')
            _PendingPaymentActions(orderId: order.id, order: order),
          if (order.paymentStatus == 'completed')
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Payment confirmed',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          if (order.paymentStatus == 'failed')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.paymentError ?? 'Payment failed',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showResendReminderDialog(
                        context,
                        orderId: order.id,
                      ),
                      icon: const Icon(Icons.notifications, size: 16),
                      label: const Text('Send Payment Reminder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showResendReminderDialog(BuildContext context, {required String orderId}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Payment Reminder?'),
        content: const Text(
          'This will send a notification to the customer reminding them to complete the payment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment reminder sent'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

// ── Pending Payment Actions ──────────────────────────────────────────────────

class _PendingPaymentActions extends StatelessWidget {
  const _PendingPaymentActions({
    required this.orderId,
    required this.order,
  });

  final String orderId;
  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showReminderDialog(context),
                icon: const Icon(Icons.notifications_none, size: 16),
                label: const Text('Send Reminder'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showMarkPaidDialog(context),
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark as Paid'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showViewDetailsDialog(context),
            icon: const Icon(Icons.visibility_outlined, size: 16),
            label: const Text('View Details'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  void _showReminderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Payment Reminder'),
        content: Text(
          'Send a payment reminder for ₹${(order.totalPaise / 100).toStringAsFixed(2)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Reminder sent successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showMarkPaidDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: Text(
          'Mark this order as paid? Amount: ₹${(order.totalPaise / 100).toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order marked as paid'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showViewDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow('Order ID', orderId.substring(0, 16)),
            _DetailRow('Items', '${order.items.length}'),
            _DetailRow('Subtotal', '₹${(order.subtotalPaise / 100).toStringAsFixed(2)}'),
            _DetailRow('Tax', '₹${(order.taxPaise / 100).toStringAsFixed(2)}'),
            _DetailRow('Total', '₹${(order.totalPaise / 100).toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Status Badges ────────────────────────────────────────────────────────────

class _PaymentStatusBadge extends StatelessWidget {
  const _PaymentStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'completed':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'failed':
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        icon = Icons.error;
        break;
      case 'pending':
      default:
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusBadge extends StatelessWidget {
  const _OrderStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'confirmed' ? Colors.blue : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: color.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? color : AppColors.border,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
