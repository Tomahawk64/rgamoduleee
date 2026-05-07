import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/models.dart';
import 'providers.dart';

String money(int amount) => 'Rs $amount';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AppScaffold(
      title: 'Sign in',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Saral Pooja',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text('Sign in with your Supabase account to book services.'),
          const SizedBox(height: 24),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: state.loading
                ? null
                : () async {
                    await ref
                        .read(appControllerProvider.notifier)
                        .signIn(
                          email: email.text.trim(),
                          password: password.text,
                        );
                    if (context.mounted &&
                        ref.read(appControllerProvider).isAuthenticated) {
                      context.go('/home');
                    }
                  },
            child: const Text('Sign in'),
          ),
          TextButton(
            onPressed: () => context.go('/signup'),
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return AppScaffold(
      title: 'Create account',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(
              labelText: 'Full name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: state.loading
                ? null
                : () async {
                    await ref
                        .read(appControllerProvider.notifier)
                        .signUp(
                          name: name.text.trim(),
                          email: email.text.trim(),
                          password: password.text,
                          phone: phone.text.trim(),
                        );
                    if (context.mounted &&
                        ref.read(appControllerProvider).isAuthenticated) {
                      context.go('/home');
                    }
                  },
            child: const Text('Create account'),
          ),
          TextButton(
            onPressed: () => context.go('/login'),
            child: const Text('I already have an account'),
          ),
        ],
      ),
    );
  }
}

class UserShell extends ConsumerWidget {
  const UserShell({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final path = GoRouterState.of(context).uri.path;
    final destinations = [
      ('/home', Icons.home_outlined, Icons.home, 'Home'),
      ('/packages', Icons.spa_outlined, Icons.spa, 'Poojas'),
      ('/special', Icons.auto_awesome_outlined, Icons.auto_awesome, 'Special'),
      ('/shop', Icons.shopping_bag_outlined, Icons.shopping_bag, 'Shop'),
      ('/account', Icons.person_outline, Icons.person, 'Account'),
    ];
    final index = destinations.indexWhere((entry) => path.startsWith(entry.$1));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (selected) =>
            context.go(destinations[selected].$1),
        destinations: destinations.map((entry) {
          final icon = entry.$1 == '/shop' && state.cartCount > 0
              ? Badge(label: Text('${state.cartCount}'), child: Icon(entry.$2))
              : Icon(entry.$2);
          return NavigationDestination(
            icon: icon,
            selectedIcon: Icon(entry.$3),
            label: entry.$4,
          );
        }).toList(),
      ),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final state = ref.watch(appControllerProvider);
    final firstPackage = repository.poojaPackages.isEmpty
        ? null
        : repository.poojaPackages.first;
    final firstPandit = repository.pandits.isEmpty
        ? null
        : repository.pandits.first;
    return AppScaffold(
      title: 'Saral Pooja',
      actions: [
        TextButton.icon(
          onPressed: () => context.go('/account'),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(money(state.wallet.balance)),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const OfferCarousel(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ActionTile(
                  icon: Icons.temple_hindu_outlined,
                  title: 'Offline pandit',
                  subtitle: 'Book a verified pandit at your address',
                  onTap: () async {
                    if (firstPackage == null) {
                      _showMessage(
                        context,
                        'No pooja package is available yet.',
                      );
                      return;
                    }
                    context.push('/book/offline/${firstPackage.id}');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ActionTile(
                  icon: Icons.chat_bubble_outline,
                  title: 'Live astrology',
                  subtitle: 'Start a timed chat with images',
                  onTap: () async {
                    if (firstPandit == null) {
                      _showMessage(
                        context,
                        'No online pandit is available yet.',
                      );
                      return;
                    }
                    context.push('/chat-booking');
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: 'Quick actions',
            action: 'View all',
            onTap: () => context.go('/packages'),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              QuickChip(
                icon: Icons.spa,
                label: 'Packages',
                onTap: () => context.go('/packages'),
              ),
              QuickChip(
                icon: Icons.auto_awesome,
                label: 'Special pooja',
                onTap: () => context.go('/special'),
              ),
              QuickChip(
                icon: Icons.shopping_cart,
                label: 'Shop',
                onTap: () => context.go('/shop'),
              ),
              QuickChip(
                icon: Icons.support_agent,
                label: 'Support',
                onTap: () => context.go('/account'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Top packages'),
          ...repository.poojaPackages
              .take(2)
              .map(
                (item) => CatalogueCard(
                  item: item,
                  actionLabel: 'Book',
                  onAction: () async {
                    context.push('/book/package/${item.id}');
                  },
                ),
              ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Active reminders'),
          if (repository.bookings
              .where((booking) => booking.userId == state.user.id)
              .isEmpty)
            const EmptyState(
              icon: Icons.notifications_none,
              text: 'No active reminders yet.',
            )
          else
            ...repository.bookings
                .where((booking) => booking.userId == state.user.id)
                .map((booking) => ReminderTile(booking: booking)),
        ],
      ),
    );
  }
}

class OfferCarousel extends StatefulWidget {
  const OfferCarousel({super.key});

  @override
  State<OfferCarousel> createState() => _OfferCarouselState();
}

class _OfferCarouselState extends State<OfferCarousel> {
  final controller = PageController();
  Timer? timer;
  int page = 0;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      page = (page + 1) % 3;
      controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final offers = [
      (
        'Corporate Satyanarayan Pooja',
        'Team blessings and office ceremonies',
        'assets/images/image3.jpg',
      ),
      (
        'Festival Booking Week',
        'Reserve pandits before rush days',
        'assets/images/image4.jpg',
      ),
      (
        'Premium Pooja Packages',
        'Samigri, pandit, and ceremony planning',
        'assets/images/image5.jpg',
      ),
    ];
    return SizedBox(
      height: 190,
      child: PageView(
        controller: controller,
        children: offers.map((offer) {
          return GestureDetector(
            onTap: () => context.go('/packages'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    offer.$3,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xFFE8892E)),
                  ),
                  Container(color: Colors.black.withValues(alpha: 0.28)),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          offer.$1,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          offer.$2,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class PackageScreen extends ConsumerWidget {
  const PackageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(repositoryProvider).poojaPackages;
    return CatalogueListScreen(
      title: 'Pooja Packages',
      searchHint: 'Search packages',
      items: items,
      actionLabel: 'Book',
      onAction: (item) async {
        context.push('/book/package/${item.id}');
      },
    );
  }
}

class SpecialPoojaScreen extends ConsumerWidget {
  const SpecialPoojaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(repositoryProvider).specialPoojas;
    return CatalogueListScreen(
      title: 'Special Pooja',
      searchHint: 'Search special poojas',
      items: items,
      actionLabel: 'Book online',
      onAction: (item) async {
        context.push('/book/special/${item.id}');
      },
    );
  }
}

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final cart = repository.cartFor(repository.currentUser.id);
    return AppScaffold(
      title: 'Shop',
      actions: [
        IconButton(
          tooltip: 'Checkout',
          onPressed: cart.isEmpty
              ? null
              : () async {
                  final order = await ref
                      .read(appControllerProvider.notifier)
                      .checkout(PaymentMethod.wallet);
                  if (context.mounted && order != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Order ${order.id} confirmed')),
                    );
                  }
                },
          icon: const Icon(Icons.shopping_cart_checkout),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (cart.isNotEmpty) ...[
            SectionHeader(title: 'Cart'),
            ...cart.map((line) => CartTile(line: line)),
            const SizedBox(height: 12),
          ],
          SectionHeader(title: 'Samigri packages'),
          ...repository.shopItems.map(
            (item) => CatalogueCard(
              item: item,
              actionLabel: 'Add',
              onAction: () =>
                  ref.read(appControllerProvider.notifier).addToCart(item.id),
            ),
          ),
        ],
      ),
    );
  }
}

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(appControllerProvider.notifier);
    final state = ref.watch(appControllerProvider);
    final repository = ref.watch(repositoryProvider);
    final config = ref.watch(appConfigProvider);
    return AppScaffold(
      title: 'Account',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfileHeader(user: state.user, balance: state.wallet.balance),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => controller.topUpWallet(5000),
                  icon: const Icon(Icons.add),
                  label: const Text('Top up'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await controller.signOut();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!config.hasSupabase) ...[
            SectionHeader(title: 'Demo role access'),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => controller.signInAs(UserRole.user),
                    child: const Text('User'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await controller.signInAs(UserRole.pandit);
                      if (context.mounted) context.go('/pandit');
                    },
                    child: const Text('Pandit'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await controller.signInAs(UserRole.admin);
                      if (context.mounted) context.go('/admin');
                    },
                    child: const Text('Admin'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SectionHeader(title: 'Saved address'),
          const InfoTile(
            icon: Icons.location_on_outlined,
            title: 'Home',
            subtitle:
                'Flat 302, Shanti Residency, MG Road, Lucknow, UP - 226001',
          ),
          SectionHeader(title: 'Booking history'),
          if (repository.bookings
              .where((booking) => booking.userId == state.user.id)
              .isEmpty)
            const EmptyState(
              icon: Icons.history,
              text: 'Bookings will appear here.',
            )
          else
            ...repository.bookings
                .where((booking) => booking.userId == state.user.id)
                .map((booking) => ReminderTile(booking: booking)),
          SectionHeader(title: 'Proof videos'),
          ...repository
              .proofsFor(state.user.id, DateTime.now())
              .map(
                (proof) => InfoTile(
                  icon: Icons.video_file_outlined,
                  title: 'Proof for ${proof.bookingId}',
                  subtitle:
                      'Available until ${proof.expiresAt.toLocal().toString().split(".").first}',
                ),
              ),
          SectionHeader(title: 'Wallet ledger'),
          ...repository
              .ledgerFor(state.user.id)
              .map(
                (entry) => InfoTile(
                  icon: entry.type == LedgerType.credit
                      ? Icons.add_circle_outline
                      : Icons.remove_circle_outline,
                  title: '${entry.type.name} ${money(entry.amount)}',
                  subtitle:
                      '${entry.reason} - balance ${money(entry.balanceAfter)}',
                ),
              ),
          SectionHeader(title: 'Support'),
          const InfoTile(
            icon: Icons.help_outline,
            title: 'Help and support',
            subtitle: 'Raise a support log from the app.',
          ),
        ],
      ),
    );
  }
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final controller = ref.read(appControllerProvider.notifier);
    return AppScaffold(
      title: 'Admin',
      leading: IconButton(
        onPressed: () => context.go('/account'),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              StatCard(
                label: 'Bookings',
                value: '${repository.bookings.length}',
              ),
              StatCard(label: 'Users', value: '${repository.users.length}'),
              StatCard(
                label: 'Packages',
                value: '${repository.poojaPackages.length}',
              ),
              StatCard(label: 'Orders', value: '${repository.orders.length}'),
            ],
          ),
          const SizedBox(height: 20),
          SectionHeader(title: 'Bookings and assignment'),
          if (repository.bookings.isEmpty)
            const EmptyState(
              icon: Icons.assignment_outlined,
              text: 'No bookings yet.',
            ),
          ...repository.bookings.map(
            (booking) => Card(
              child: ListTile(
                title: Text(booking.title),
                subtitle: Text(
                  'Full address: ${booking.address?.full ?? 'Online'}\nStatus: ${booking.status.name}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<BookingStatus>(
                  onSelected: (status) => controller.adminUpdate(
                    booking.id,
                    status,
                    panditId: status == BookingStatus.panditAssigned
                        ? repository.pandits.first.id
                        : booking.panditId,
                  ),
                  itemBuilder: (_) => BookingStatus.values
                      .map(
                        (status) => PopupMenuItem(
                          value: status,
                          child: Text(status.name),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
          SectionHeader(title: 'Proof upload'),
          ...repository.bookings
              .where((booking) => booking.type == BookingType.specialPooja)
              .map((booking) {
                return ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(booking.title),
                  subtitle: const Text(
                    'Upload Cloudflare proof video, max 300 MB',
                  ),
                  trailing: FilledButton(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(
                        type: FileType.video,
                        withData: true,
                      );
                      final file = picked?.files.single;
                      final bytes = file?.bytes;
                      if (file == null || bytes == null) return;
                      await controller.uploadProofBytes(
                        booking.id,
                        bytes: bytes,
                        fileName: file.name,
                      );
                    },
                    child: const Text('Upload'),
                  ),
                );
              }),
          SectionHeader(title: 'Catalog CRUD'),
          ...repository.poojaPackages.map(
            (item) => CatalogueAdminTile(area: 'packages', item: item),
          ),
          ...repository.specialPoojas.map(
            (item) => CatalogueAdminTile(area: 'special', item: item),
          ),
          ...repository.shopItems.map(
            (item) => CatalogueAdminTile(area: 'shop', item: item),
          ),
        ],
      ),
    );
  }
}

class PanditDashboardScreen extends ConsumerWidget {
  const PanditDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final state = ref.watch(appControllerProvider);
    final assignments = repository.bookings
        .where((booking) => booking.panditId == state.user.id)
        .toList();
    return AppScaffold(
      title: 'Pandit dashboard',
      leading: IconButton(
        onPressed: () => context.go('/account'),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ProfileHeader(user: state.user, balance: 0, hideMoney: true),
          const SizedBox(height: 16),
          const InfoTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy mode',
            subtitle:
                'You can see assignments, timers, rough address, and completion status only.',
          ),
          SectionHeader(title: 'Assignments'),
          if (assignments.isEmpty)
            const EmptyState(
              icon: Icons.assignment_ind_outlined,
              text: 'No assigned bookings yet.',
            ),
          ...assignments.map(
            (booking) => Card(
              child: ListTile(
                title: Text(booking.title),
                subtitle: Text(
                  'Rough address: ${booking.panditSafeAddress}\nStatus: ${booking.status.name}',
                ),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () => ref
                      .read(appControllerProvider.notifier)
                      .adminUpdate(booking.id, BookingStatus.completed),
                  child: const Text('Complete'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(repositoryProvider);
    final booking = repository.bookings.firstWhere((entry) => entry.id == id);
    return AppScaffold(
      title: 'Booking',
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            booking.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text('Status: ${booking.status.name}'),
          Text('Payment: ${booking.paymentId}'),
          Text('Schedule: ${booking.scheduledAt.toLocal()}'),
          const SizedBox(height: 12),
          InfoTile(
            icon: Icons.location_on_outlined,
            title: 'Address',
            subtitle: booking.address?.full ?? 'Online service',
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final input = TextEditingController();
  Timer? timer;
  Duration remaining = const Duration(minutes: 10);

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final repository = ref.read(repositoryProvider);
      final session = repository.chatSessionById(widget.sessionId);
      setState(() {
        remaining = session?.remaining(DateTime.now()) ?? Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    final messages = repository.messagesFor(widget.sessionId);
    return AppScaffold(
      title: 'Live astrology chat',
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    remaining == Duration.zero
                        ? 'Session expired'
                        : 'Timed session active - ${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                  ),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(appControllerProvider.notifier)
                      .extendChat(widget.sessionId, 5),
                  child: const Text('Extend'),
                ),
              ],
            ),
          ),
          Expanded(
            child: messages.isEmpty
                ? const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    text: 'No messages yet.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final mine =
                          message.senderId == repository.currentUser.id;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(maxWidth: 280),
                          decoration: BoxDecoration(
                            color: mine
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            message.imageUrl == null
                                ? message.text
                                : '${message.text}\n${message.imageUrl}',
                            style: TextStyle(
                              color: mine ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Upload image',
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(
                      type: FileType.image,
                      withData: true,
                    );
                    final file = picked?.files.single;
                    final bytes = file?.bytes;
                    if (file == null || bytes == null) return;
                    await ref
                        .read(appControllerProvider.notifier)
                        .sendImageMessage(
                          widget.sessionId,
                          text: 'Shared image: ${file.name}',
                          bytes: bytes,
                        );
                  },
                  icon: const Icon(Icons.image_outlined),
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    decoration: const InputDecoration(
                      hintText: 'Message pandit',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Send',
                  onPressed: () {
                    final text = input.text.trim();
                    if (text.isEmpty) return;
                    ref
                        .read(appControllerProvider.notifier)
                        .sendMessage(widget.sessionId, text);
                    input.clear();
                  },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CatalogueListScreen extends StatefulWidget {
  const CatalogueListScreen({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String searchHint;
  final List<CatalogueItem> items;
  final String actionLabel;
  final Future<void> Function(CatalogueItem item) onAction;

  @override
  State<CatalogueListScreen> createState() => _CatalogueListScreenState();
}

class _CatalogueListScreenState extends State<CatalogueListScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items
        .where((item) => item.title.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return AppScaffold(
      title: widget.title,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: widget.searchHint,
            ),
            onChanged: (value) => setState(() => query = value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: const [
              FilterChip(
                label: Text('Samigri included'),
                selected: true,
                onSelected: null,
              ),
              FilterChip(
                label: Text('Online'),
                selected: false,
                onSelected: null,
              ),
              FilterChip(
                label: Text('Under Rs 5000'),
                selected: false,
                onSelected: null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              text: 'No matching services.',
            )
          else
            ...filtered.map(
              (item) => CatalogueCard(
                item: item,
                actionLabel: widget.actionLabel,
                onAction: () => widget.onAction(item),
              ),
            ),
        ],
      ),
    );
  }
}

class BookingFormScreen extends ConsumerStatefulWidget {
  const BookingFormScreen({
    required this.type,
    required this.catalogueId,
    super.key,
  });

  final String type;
  final String catalogueId;

  @override
  ConsumerState<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends ConsumerState<BookingFormScreen> {
  final formKey = GlobalKey<FormState>();
  final label = TextEditingController(text: 'Home');
  final line1 = TextEditingController();
  final city = TextEditingController();
  final stateName = TextEditingController();
  final pincode = TextEditingController();
  final notes = TextEditingController();
  DateTime scheduledAt = DateTime.now().add(const Duration(days: 1));
  PaymentMethod paymentMethod = PaymentMethod.wallet;
  bool saveAsDefault = true;

  BookingType get bookingType => switch (widget.type) {
    'offline' => BookingType.offlinePandit,
    'package' => BookingType.poojaPackage,
    'special' => BookingType.specialPooja,
    _ => BookingType.poojaPackage,
  };

  bool get needsAddress =>
      bookingType == BookingType.offlinePandit ||
      bookingType == BookingType.poojaPackage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillAddress());
  }

  @override
  void dispose() {
    label.dispose();
    line1.dispose();
    city.dispose();
    stateName.dispose();
    pincode.dispose();
    notes.dispose();
    super.dispose();
  }

  void _prefillAddress() {
    final repository = ref.read(repositoryProvider);
    final saved = repository.addressesFor(repository.currentUser.id);
    if (saved.isEmpty) return;
    final preferred = saved.firstWhere(
      (address) => address.isDefault,
      orElse: () => saved.first,
    );
    setState(() {
      label.text = preferred.label;
      line1.text = preferred.line1;
      city.text = preferred.city;
      stateName.text = preferred.state;
      pincode.text = preferred.pincode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    final items = switch (bookingType) {
      BookingType.specialPooja => repository.specialPoojas,
      _ => repository.poojaPackages,
    };
    final item = items.firstWhere((entry) => entry.id == widget.catalogueId);
    return AppScaffold(
      title: 'Book ${item.title}',
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CatalogueCard(
              item: item,
              actionLabel: money(item.price),
              onAction: () {},
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Preferred date and time'),
              subtitle: Text(scheduledAt.toLocal().toString().split('.').first),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickSchedule,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              items: PaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(
                        method == PaymentMethod.wallet
                            ? 'Wallet balance'
                            : 'Razorpay',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                paymentMethod = value ?? PaymentMethod.wallet;
              }),
            ),
            if (needsAddress) ...[
              const SizedBox(height: 18),
              SectionHeader(title: 'Service address'),
              _RequiredField(controller: label, label: 'Address label'),
              _RequiredField(
                controller: line1,
                label: 'Full address',
                maxLines: 2,
              ),
              Row(
                children: [
                  Expanded(
                    child: _RequiredField(controller: city, label: 'City'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RequiredField(
                      controller: stateName,
                      label: 'State',
                    ),
                  ),
                ],
              ),
              _RequiredField(
                controller: pincode,
                label: 'PIN code',
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save this address for future bookings'),
                value: saveAsDefault,
                onChanged: (value) => setState(() => saveAsDefault = value),
              ),
            ],
            const SizedBox(height: 18),
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: bookingType == BookingType.specialPooja
                    ? 'Sankalp, gotra, and important details'
                    : 'Special instructions',
                prefixIcon: const Icon(Icons.notes_outlined),
              ),
              validator: (value) {
                if (bookingType == BookingType.specialPooja &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Special pooja details are required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_outline),
              label: Text('Confirm booking - ${money(item.price)}'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSchedule() async {
    final date = await showDatePicker(
      context: context,
      initialDate: scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(scheduledAt),
    );
    if (time == null) return;
    setState(() {
      scheduledAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    final repository = ref.read(repositoryProvider);
    Address? address;
    if (needsAddress) {
      address = Address(
        id: 'addr_${DateTime.now().microsecondsSinceEpoch}',
        userId: repository.currentUser.id,
        label: label.text.trim(),
        line1: line1.text.trim(),
        city: city.text.trim(),
        state: stateName.text.trim(),
        pincode: pincode.text.trim(),
        isDefault: saveAsDefault,
      );
      if (saveAsDefault) {
        address = await repository.saveAddress(address);
      }
    }
    final booking = await ref
        .read(appControllerProvider.notifier)
        .createBooking(
          type: bookingType,
          catalogueId: widget.catalogueId,
          scheduledAt: scheduledAt,
          paymentMethod: paymentMethod,
          address: address,
          notes: notes.text.trim(),
        );
    if (mounted && booking != null) context.go('/booking/${booking.id}');
  }
}

class ChatBookingScreen extends ConsumerStatefulWidget {
  const ChatBookingScreen({super.key});

  @override
  ConsumerState<ChatBookingScreen> createState() => _ChatBookingScreenState();
}

class _ChatBookingScreenState extends ConsumerState<ChatBookingScreen> {
  String? panditId;
  int minutes = 10;
  PaymentMethod paymentMethod = PaymentMethod.wallet;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(repositoryProvider);
    final pandits = repository.pandits
        .where((pandit) => pandit.isOnline)
        .toList();
    panditId ??= pandits.isEmpty ? null : pandits.first.id;
    final selected = pandits
        .where((pandit) => pandit.id == panditId)
        .firstOrNull;
    final total = (selected?.chatPricePerMinute ?? 0) * minutes;
    return AppScaffold(
      title: 'Book live astrology chat',
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (pandits.isEmpty)
            const EmptyState(
              icon: Icons.person_off_outlined,
              text: 'No pandits are online right now.',
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: panditId,
              decoration: const InputDecoration(
                labelText: 'Select pandit',
                prefixIcon: Icon(Icons.person_search_outlined),
              ),
              items: pandits
                  .map(
                    (pandit) => DropdownMenuItem(
                      value: pandit.id,
                      child: Text(
                        '${pandit.name} - ${money(pandit.chatPricePerMinute)}/min',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => panditId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: minutes,
              decoration: const InputDecoration(
                labelText: 'Session duration',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              items: const [10, 15, 30, 45]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('$value minutes'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => minutes = value ?? 10),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<PaymentMethod>(
              initialValue: paymentMethod,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              items: PaymentMethod.values
                  .map(
                    (method) => DropdownMenuItem(
                      value: method,
                      child: Text(
                        method == PaymentMethod.wallet ? 'Wallet' : 'Razorpay',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() {
                paymentMethod = value ?? PaymentMethod.wallet;
              }),
            ),
            const SizedBox(height: 20),
            InfoTile(
              icon: Icons.lock_outline,
              title: 'Privacy protected',
              subtitle:
                  'Pandits can only see your chat messages and uploaded images for this session.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                final id = panditId;
                if (id == null) return;
                final session = await ref
                    .read(appControllerProvider.notifier)
                    .bookChat(id, minutes, paymentMethod: paymentMethod);
                if (!mounted || session == null) return;
                if (context.mounted) {
                  context.go('/chat/${session.id}');
                }
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: Text('Start session - ${money(total)}'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequiredField extends StatelessWidget {
  const _RequiredField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
        validator: (value) => value == null || value.trim().isEmpty
            ? '$label is required.'
            : null,
      ),
    );
  }
}

class AppScaffold extends ConsumerWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    super.key,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions, leading: leading),
      body: Stack(
        children: [
          child,
          if (state.loading) const LinearProgressIndicator(),
          if (state.error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ActionTile extends StatelessWidget {
  const ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(subtitle, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogueCard extends StatelessWidget {
  const CatalogueCard({
    required this.item,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });
  final CatalogueItem item;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                item.imageUrl,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFFFE2BD),
                  child: SizedBox(width: 88, height: 88),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item.durationMinutes} min - ${item.panditCoverage} - ${item.samigriIncluded ? 'Samigri included' : 'Samigri extra'}',
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: item.includedItems
                        .take(3)
                        .map(
                          (entry) => Chip(
                            label: Text(entry),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(
                  money(item.price),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CartTile extends ConsumerWidget {
  const CartTile({required this.line, super.key});
  final CartLine line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(line.item.title),
        subtitle: Text('${money(line.item.price)} x ${line.quantity}'),
        trailing: SizedBox(
          width: 120,
          child: Row(
            children: [
              IconButton(
                onPressed: () => ref
                    .read(appControllerProvider.notifier)
                    .updateCart(line.item.id, line.quantity - 1),
                icon: const Icon(Icons.remove),
              ),
              Text('${line.quantity}'),
              IconButton(
                onPressed: () => ref
                    .read(appControllerProvider.notifier)
                    .updateCart(line.item.id, line.quantity + 1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogueAdminTile extends ConsumerWidget {
  const CatalogueAdminTile({required this.area, required this.item, super.key});
  final String area;
  final CatalogueItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(item.title),
        subtitle: Text(
          '$area - ${money(item.price)} - order ${item.sortOrder}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              await _showCatalogueEditor(context, ref);
            } else if (action == 'reorder') {
              await ref
                  .read(repositoryProvider)
                  .upsertCatalogue(
                    area: area,
                    item: item.copyWith(sortOrder: item.sortOrder + 1),
                  );
              ref.invalidate(appControllerProvider);
            } else if (action == 'delete') {
              await ref
                  .read(repositoryProvider)
                  .deleteCatalogue(area: area, id: item.id);
              ref.invalidate(appControllerProvider);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'reorder', child: Text('Move down')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _showCatalogueEditor(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController(text: item.title);
    final description = TextEditingController(text: item.description);
    final price = TextEditingController(text: item.price.toString());
    final imageUrl = TextEditingController(text: item.imageUrl);
    final included = TextEditingController(text: item.includedItems.join(', '));
    final duration = TextEditingController(
      text: item.durationMinutes.toString(),
    );
    final stock = TextEditingController(text: item.stock?.toString() ?? '');
    final result = await showDialog<CatalogueItem>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Edit ${item.title}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: price,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: imageUrl,
                  decoration: const InputDecoration(
                    labelText: 'Image URL / asset path',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: included,
                  decoration: const InputDecoration(
                    labelText: 'Included items, comma separated',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: duration,
                  decoration: const InputDecoration(
                    labelText: 'Duration minutes',
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (area == 'shop') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: stock,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  item.copyWith(
                    title: title.text.trim(),
                    description: description.text.trim(),
                    price: int.tryParse(price.text.trim()) ?? item.price,
                    imageUrl: imageUrl.text.trim(),
                    includedItems: included.text
                        .split(',')
                        .map((entry) => entry.trim())
                        .where((entry) => entry.isNotEmpty)
                        .toList(),
                    durationMinutes:
                        int.tryParse(duration.text.trim()) ??
                        item.durationMinutes,
                    stock: stock.text.trim().isEmpty
                        ? item.stock
                        : int.tryParse(stock.text.trim()),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    title.dispose();
    description.dispose();
    price.dispose();
    imageUrl.dispose();
    included.dispose();
    duration.dispose();
    stock.dispose();
    if (result == null) return;
    await ref
        .read(repositoryProvider)
        .upsertCatalogue(area: area, item: result);
    ref.invalidate(appControllerProvider);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.title,
    this.action,
    this.onTap,
    super.key,
  });
  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onTap, child: Text(action!)),
        ],
      ),
    );
  }
}

class QuickChip extends StatelessWidget {
  const QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class ReminderTile extends StatelessWidget {
  const ReminderTile({required this.booking, super.key});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return InfoTile(
      icon: Icons.notifications_active_outlined,
      title: booking.title,
      subtitle:
          '${booking.status.name} - ${booking.scheduledAt.toLocal().toString().split(".").first}',
    );
  }
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.user,
    required this.balance,
    this.hideMoney = false,
    super.key,
  });
  final AppUser user;
  final int balance;
  final bool hideMoney;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 28, child: Text(user.name.substring(0, 1))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text('${user.email} - ${user.role.name}'),
                  const Text('Phone and email verified'),
                ],
              ),
            ),
            if (!hideMoney)
              Text(
                money(balance),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
          ],
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  const InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    super.key,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.icon, required this.text, super.key});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({required this.label, required this.value, super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
