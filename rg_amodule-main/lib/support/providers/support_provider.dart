import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/providers/supabase_provider.dart';
import '../models/support_ticket.dart';
import '../repository/support_repository.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(supabaseClientProvider));
});

final supportRealtimeTickProvider = StreamProvider<int>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final controller = StreamController<int>.broadcast();
  var tick = 0;

  final channel = client
      .channel('support-tickets-realtime')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'support_tickets',
        callback: (_) {
          tick += 1;
          controller.add(tick);
        },
      )
      .subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

final mySupportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  return ref.watch(supportRepositoryProvider).fetchMyTickets(user.id);
});

final adminSupportTicketsProvider = FutureProvider.family<List<SupportTicket>, String?>((ref, status) async {
  return ref.watch(supportRepositoryProvider).fetchAllTicketsForAdmin(status: status);
});
