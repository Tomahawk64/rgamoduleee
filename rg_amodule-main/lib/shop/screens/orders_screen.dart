// lib/shop/screens/orders_screen.dart

// Shows the authenticated user's past shop orders.



import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart';



import '../../core/providers/supabase_provider.dart';

import '../../core/theme/app_colors.dart';



class OrdersScreen extends ConsumerStatefulWidget {

  const OrdersScreen({super.key});



  @override

  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();

}



class _OrdersScreenState extends ConsumerState<OrdersScreen> {

  List<Map<String, dynamic>> _orders = [];

  bool _loading = true;

  String? _error;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    setState(() {

      _loading = true;

      _error = null;

    });

    try {

      final client = ref.read(supabaseClientProvider);

      final uid = client.auth.currentUser?.id;

      if (uid == null) {

        setState(() {

          _loading = false;

          _orders = [];

        });

        return;

      }



      final rows = await client

          .from('orders')

          .select('id, created_at, status, total_paise, items, shipping_addr')

          .eq('user_id', uid)

          .order('created_at', ascending: false);



      setState(() {

        _orders = List<Map<String, dynamic>>.from(rows as List);

        _loading = false;

      });

    } on PostgrestException catch (e) {

      setState(() {

        _error = e.message;

        _loading = false;

      });

    } catch (e) {

      setState(() {

        _error = e.toString();

        _loading = false;

      });

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        title: const Text('Order History',

            style: TextStyle(fontWeight: FontWeight.w700)),

        backgroundColor: Colors.white,

        foregroundColor: AppColors.textPrimary,

        elevation: 0,

        surfaceTintColor: Colors.transparent,

        actions: [

          if (_loading)

            const Padding(

              padding: EdgeInsets.all(14),

              child: SizedBox(

                  width: 18,

                  height: 18,

                  child: CircularProgressIndicator(strokeWidth: 2)),

            )

          else

            IconButton(

              icon: const Icon(Icons.refresh),

              onPressed: _load,

            ),

        ],

      ),

      body: _buildBody(),

    );

  }



  Widget _buildBody() {

    if (_loading && _orders.isEmpty) {

      return const Center(child: CircularProgressIndicator());

    }



    if (_error != null) {

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.error_outline,

                size: 48, color: AppColors.error),

            const SizedBox(height: 12),

            Text(_error!,

                textAlign: TextAlign.center,

                style:

                    const TextStyle(color: AppColors.textSecondary)),

            const SizedBox(height: 20),

            FilledButton.icon(

              onPressed: _load,

              icon: const Icon(Icons.refresh, size: 18),

              label: const Text('Retry'),

            ),

          ],

        ),

      );

    }



    if (_orders.isEmpty) {

      return Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Icon(Icons.shopping_bag_outlined,

                size: 64,

                color: AppColors.textHint.withValues(alpha: 0.6)),

            const SizedBox(height: 16),

            const Text('No orders yet',

                style: TextStyle(

                    fontSize: 16,

                    fontWeight: FontWeight.w600,

                    color: AppColors.textPrimary)),

            const SizedBox(height: 8),

            const Text('Your completed orders will appear here',

                style: TextStyle(

                    color: AppColors.textSecondary, fontSize: 13)),

          ],

        ),

      );

    }



    return RefreshIndicator(

      onRefresh: _load,

      child: ListView.separated(

        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),

        separatorBuilder: (_, _) => const SizedBox(height: 10),

        itemCount: _orders.length,

        itemBuilder: (_, i) => _OrderCard(order: _orders[i]),

      ),

    );

  }

}



// ── Order card ─────────────────────────────────────────────────────────────────



class _OrderCard extends StatelessWidget {

  const _OrderCard({required this.order});

  final Map<String, dynamic> order;



  @override

  Widget build(BuildContext context) {

    final status = order['status'] as String? ?? 'confirmed';

    final totalPaise = order['total_paise'] as int? ?? 0;

    final items = List<Map<String, dynamic>>.from(

        (order['items'] as List?) ?? []);

    final createdAt = DateTime.tryParse(

            order['created_at'] as String? ?? '') ??

        DateTime.now();

    final orderId = (order['id'] as String?)?.substring(0, 8).toUpperCase() ??

        '--------';



    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.04),

            blurRadius: 4,

            offset: const Offset(0, 2),

          ),

        ],

      ),

      child: Column(

        children: [

          // Header

          Padding(

            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),

            child: Row(

              children: [

                const Icon(Icons.receipt_long_outlined,

                    size: 18, color: AppColors.primary),

                const SizedBox(width: 8),

                Text(

                  'ORD-$orderId',

                  style: const TextStyle(

                    fontWeight: FontWeight.bold,

                    fontSize: 14,

                    color: AppColors.textPrimary,

                  ),

                ),

                const Spacer(),

                _StatusBadge(status: status),

              ],

            ),

          ),



          // Items

          if (items.isNotEmpty) ...[

            const Divider(height: 1),

            ListView.builder(

              shrinkWrap: true,

              physics: const NeverScrollableScrollPhysics(),

              padding: const EdgeInsets.symmetric(

                  horizontal: 14, vertical: 8),

              itemCount: items.length,

              itemBuilder: (_, i) {

                final item = items[i];

                final name = item['name'] as String? ?? 'Item';

                final qty = item['quantity'] as int? ?? 1;

                final unitPaise = item['unit_paise'] as int? ?? 0;

                return Padding(

                  padding: const EdgeInsets.symmetric(vertical: 3),

                  child: Row(

                    children: [

                      Expanded(

                        child: Text(

                          '$name × $qty',

                          style: const TextStyle(fontSize: 13),

                          overflow: TextOverflow.ellipsis,

                        ),

                      ),

                      Text(

                        '₹${((unitPaise * qty) / 100).toStringAsFixed(0)}',

                        style: const TextStyle(

                            fontSize: 13,

                            color: AppColors.textSecondary),

                      ),

                    ],

                  ),

                );

              },

            ),

          ],



          // Footer

          const Divider(height: 1),

          Padding(

            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),

            child: Row(

              children: [

                Text(

                  _formatDate(createdAt),

                  style: const TextStyle(

                      fontSize: 12, color: AppColors.textSecondary),

                ),

                const Spacer(),

                Text(

                  'Total: ₹${(totalPaise / 100).toStringAsFixed(0)}',

                  style: const TextStyle(

                    fontWeight: FontWeight.bold,

                    fontSize: 14,

                    color: AppColors.primary,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  String _formatDate(DateTime dt) {

    const months = [

      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',

      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'

    ];

    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';

  }

}



class _StatusBadge extends StatelessWidget {

  const _StatusBadge({required this.status});

  final String status;



  @override

  Widget build(BuildContext context) {

    final (color, bg) = switch (status) {

      'confirmed' => (const Color(0xFF10B981), const Color(0xFFECFDF5)),

      'processing' => (const Color(0xFFF59E0B), const Color(0xFFFFFBEB)),

      'shipped' => (const Color(0xFF3B82F6), const Color(0xFFEFF6FF)),

      'delivered' => (AppColors.success, const Color(0xFFECFDF5)),

      'cancelled' => (AppColors.error, const Color(0xFFFEF2F2)),

      _ => (AppColors.textSecondary, AppColors.background),

    };



    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),

      decoration: BoxDecoration(

        color: bg,

        borderRadius: BorderRadius.circular(8),

        border: Border.all(color: color.withValues(alpha: 0.3)),

      ),

      child: Text(

        status.toUpperCase(),

        style: TextStyle(

          fontSize: 10,

          fontWeight: FontWeight.bold,

          color: color,

          letterSpacing: 0.3,

        ),

      ),

    );

  }

}

