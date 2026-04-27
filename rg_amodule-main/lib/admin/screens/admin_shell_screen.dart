// lib/admin/screens/admin_shell_screen.dart

// Dedicated admin shell — replaces the regular bottom-nav shell for admin users.

// Tabs: Overview · Bookings · Catalogue · Pandits · Users



import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../auth/providers/auth_provider.dart';

import '../../booking/models/booking_status.dart';

import '../../core/constants/demo_config.dart';

import '../../core/router/app_router.dart';

import '../../core/theme/app_colors.dart';

import '../models/admin_models.dart';

import '../providers/admin_providers.dart';

import '../providers/admin_package_catalog_provider.dart';

import 'admin_bookings_screen.dart';

import 'admin_pandits_screen.dart';

import 'admin_users_screen.dart';

import '_admin_overview_tab.dart';

import '_admin_catalogue_tab.dart';



class AdminShellScreen extends ConsumerStatefulWidget {

  const AdminShellScreen({super.key});



  @override

  ConsumerState<AdminShellScreen> createState() => _AdminShellScreenState();

}



class _AdminShellScreenState extends ConsumerState<AdminShellScreen> {

  int _selectedIndex = 0;



  static const _tabs = [

    _AdminTab(label: 'Overview',  icon: Icons.dashboard_outlined,      activeIcon: Icons.dashboard,        color: Color(0xFF8C2A17)),

    _AdminTab(label: 'Bookings',  icon: Icons.list_alt_outlined,        activeIcon: Icons.list_alt,          color: Color(0xFF2E7D32)),

    _AdminTab(label: 'Catalogue', icon: Icons.temple_hindu_outlined,    activeIcon: Icons.temple_hindu,      color: Color(0xFF6A1B9A)),

    _AdminTab(label: 'Pandits',   icon: Icons.supervised_user_circle_outlined, activeIcon: Icons.supervised_user_circle, color: Color(0xFF0277BD)),

    _AdminTab(label: 'Users',     icon: Icons.people_outline,           activeIcon: Icons.people,            color: Color(0xFF00695C)),

  ];



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      ref.read(adminProvider.notifier).load();

      ref.read(adminPackageCatalogProvider.notifier).load();

    });

  }



  @override

  Widget build(BuildContext context) {

    // Error listener

    ref.listen<AdminState>(adminProvider, (_, next) {

      if (next.error != null && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(

          content: Text(next.error!),

          backgroundColor: AppColors.error,

          action: SnackBarAction(

            label: 'Dismiss',

            textColor: Colors.white,

            onPressed: () => ref.read(adminProvider.notifier).clearError(),

          ),

        ));

        ref.read(adminProvider.notifier).clearError();

      }

    });



    final state = ref.watch(adminProvider);

    final catalogState = ref.watch(adminPackageCatalogProvider);

    final user = ref.watch(currentUserProvider);



    final bodies = [

      AdminOverviewTab(state: state, catalogState: catalogState, userName: user?.name ?? ''),

      const AdminBookingsScreen(),

      AdminCatalogueTab(state: state, catalogState: catalogState),

      const AdminPanditsScreen(),

      const AdminUsersScreen(),

    ];



    final tab = _tabs[_selectedIndex];



    return Scaffold(

      backgroundColor: const Color(0xFFF5F5F5),

      appBar: _AdminAppBar(

        title: tab.label,

        accentColor: tab.color,

        isLoading: state.loading || catalogState.loading,

        onRefresh: () {

          ref.read(adminProvider.notifier).load();

          ref.read(adminPackageCatalogProvider.notifier).load();

        },

        onLogout: () async {

          await ref.read(authProvider.notifier).logout();

          if (context.mounted) context.go('/login');

        },

        onEditProfile: () => context.push('/account/edit-profile'),

        onSupportTickets: () => context.push(Routes.adminSupportTickets),

        demoMode: DemoConfig.demoMode,

      ),

      body: IndexedStack(

        index: _selectedIndex,

        children: bodies,

      ),

      bottomNavigationBar: _AdminBottomNav(

        selectedIndex: _selectedIndex,

        tabs: _tabs,

        bookingBadge: state.bookings.where((b) => b.status.isActive).length,

        onTap: (i) => setState(() => _selectedIndex = i),

      ),

    );

  }

}



// ── App bar ───────────────────────────────────────────────────────────────────



class _AdminAppBar extends StatelessWidget implements PreferredSizeWidget {

  const _AdminAppBar({

    required this.title,

    required this.accentColor,

    required this.isLoading,

    required this.onRefresh,

    required this.onLogout,

    required this.demoMode,

    this.onEditProfile,

    this.onSupportTickets,

  });



  final String title;

  final Color accentColor;

  final bool isLoading;

  final VoidCallback onRefresh;

  final VoidCallback onLogout;

  final bool demoMode;

  final VoidCallback? onEditProfile;

  final VoidCallback? onSupportTickets;



  @override

  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 2);



  @override

  Widget build(BuildContext context) {

    return AppBar(

      backgroundColor: Colors.white,

      foregroundColor: AppColors.textPrimary,

      elevation: 0,

      surfaceTintColor: Colors.transparent,

      titleSpacing: 16,

      title: Row(

        children: [

          Container(

            width: 32,

            height: 32,

            decoration: BoxDecoration(

              gradient: LinearGradient(

                colors: [accentColor, accentColor.withValues(alpha: 0.7)],

                begin: Alignment.topLeft,

                end: Alignment.bottomRight,

              ),

              borderRadius: BorderRadius.circular(8),

            ),

            child: const Icon(Icons.admin_panel_settings_rounded,

                color: Colors.white, size: 18),

          ),

          const SizedBox(width: 10),

          Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            mainAxisSize: MainAxisSize.min,

            children: [

              Text(

                title,

                style: const TextStyle(

                  fontWeight: FontWeight.w800,

                  fontSize: 16,

                  color: AppColors.textPrimary,

                ),

              ),

              if (demoMode)

                const Text(

                  'Demo Mode',

                  style: TextStyle(

                    fontSize: 9,

                    color: AppColors.info,

                    fontWeight: FontWeight.w600,

                    letterSpacing: 0.5,

                  ),

                ),

            ],

          ),

        ],

      ),

      actions: [

        if (isLoading)

          const Padding(

            padding: EdgeInsets.symmetric(horizontal: 12),

            child: SizedBox(

              width: 18,

              height: 18,

              child: CircularProgressIndicator(strokeWidth: 2),

            ),

          )

        else

          IconButton(

            icon: const Icon(Icons.refresh_rounded),

            tooltip: 'Refresh',

            onPressed: onRefresh,

          ),

        if (onSupportTickets != null)

          IconButton(

            icon: const Icon(Icons.support_agent_rounded),

            tooltip: 'Support Tickets',

            onPressed: onSupportTickets,

          ),

        if (onEditProfile != null)

          IconButton(

            icon: const Icon(Icons.person_outline_rounded),

            tooltip: 'Edit Profile',

            onPressed: onEditProfile,

          ),

        IconButton(

          icon: const Icon(Icons.logout_rounded),

          tooltip: 'Sign Out',

          onPressed: onLogout,

        ),

        const SizedBox(width: 4),

      ],

      bottom: PreferredSize(

        preferredSize: const Size.fromHeight(2),

        child: Container(

          height: 2,

          decoration: BoxDecoration(

            gradient: LinearGradient(

              colors: [accentColor.withValues(alpha: 0.6), accentColor.withValues(alpha: 0.0)],

            ),

          ),

        ),

      ),

    );

  }

}



// ── Bottom nav ────────────────────────────────────────────────────────────────



class _AdminBottomNav extends StatelessWidget {

  const _AdminBottomNav({

    required this.selectedIndex,

    required this.tabs,

    required this.bookingBadge,

    required this.onTap,

  });



  final int selectedIndex;

  final List<_AdminTab> tabs;

  final int bookingBadge;

  final ValueChanged<int> onTap;



  @override

  Widget build(BuildContext context) {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withValues(alpha: 0.08),

            blurRadius: 12,

            offset: const Offset(0, -2),

          ),

        ],

      ),

      child: SafeArea(

        child: SizedBox(

          height: 60,

          child: Row(

            children: List.generate(tabs.length, (i) {

              final tab = tabs[i];

              final isSelected = i == selectedIndex;

              final showBadge = i == 1 && bookingBadge > 0; // Bookings tab



              return Expanded(

                child: GestureDetector(

                  onTap: () => onTap(i),

                  behavior: HitTestBehavior.opaque,

                  child: AnimatedContainer(

                    duration: const Duration(milliseconds: 200),

                    child: Column(

                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [

                        Stack(

                          clipBehavior: Clip.none,

                          children: [

                            AnimatedContainer(

                              duration: const Duration(milliseconds: 200),

                              padding: const EdgeInsets.symmetric(

                                  horizontal: 12, vertical: 4),

                              decoration: BoxDecoration(

                                color: isSelected

                                    ? tab.color.withValues(alpha: 0.12)

                                    : Colors.transparent,

                                borderRadius: BorderRadius.circular(20),

                              ),

                              child: Icon(

                                isSelected ? tab.activeIcon : tab.icon,

                                size: 22,

                                color: isSelected

                                    ? tab.color

                                    : AppColors.textSecondary,

                              ),

                            ),

                            if (showBadge)

                              Positioned(

                                top: -2,

                                right: -2,

                                child: Container(

                                  width: 16,

                                  height: 16,

                                  decoration: BoxDecoration(

                                    color: AppColors.error,

                                    shape: BoxShape.circle,

                                    border: Border.all(

                                        color: Colors.white, width: 1.5),

                                  ),

                                  child: Center(

                                    child: Text(

                                      bookingBadge > 99

                                          ? '99+'

                                          : '$bookingBadge',

                                      style: const TextStyle(

                                        fontSize: 8,

                                        fontWeight: FontWeight.bold,

                                        color: Colors.white,

                                      ),

                                    ),

                                  ),

                                ),

                              ),

                          ],

                        ),

                        const SizedBox(height: 2),

                        Text(

                          tab.label,

                          style: TextStyle(

                            fontSize: 10,

                            fontWeight: isSelected

                                ? FontWeight.w700

                                : FontWeight.normal,

                            color: isSelected

                                ? tab.color

                                : AppColors.textSecondary,

                          ),

                        ),

                      ],

                    ),

                  ),

                ),

              );

            }),

          ),

        ),

      ),

    );

  }

}



class _AdminTab {

  const _AdminTab({

    required this.label,

    required this.icon,

    required this.activeIcon,

    required this.color,

  });



  final String label;

  final IconData icon;

  final IconData activeIcon;

  final Color color;

}

