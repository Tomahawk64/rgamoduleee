import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../../core/constants/demo_config.dart';
import '../../core/providers/supabase_provider.dart';
import '../models/app_notification.dart';
import '../repository/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<INotificationsRepository>((ref) {
  if (DemoConfig.demoMode) return MockNotificationsRepository();
  return SupabaseNotificationsRepository(ref.watch(supabaseClientProvider));
});

final notificationsStreamProvider = StreamProvider<List<AppNotification>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream<List<AppNotification>>.empty();
  return ref.watch(notificationsRepositoryProvider).watchNotifications(user.id);
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsStreamProvider);
  return async.maybeWhen(
    data: (items) => items.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});