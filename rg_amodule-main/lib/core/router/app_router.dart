// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import '../../auth/models/auth_state.dart';

import '../../auth/providers/auth_provider.dart';

import '../../auth/screens/modern_login_screen.dart';

import '../../auth/screens/signup_screen.dart';

import '../../home/screens/home_screen.dart';

import '../../packages/models/package_model.dart';

import '../../packages/screens/packages_screen.dart';

import '../../packages/screens/package_detail_screen.dart';

import '../../booking/screens/booking_screen.dart';

import '../../booking/screens/booking_wizard_screen.dart';

import '../../booking/screens/booking_detail_screen.dart';

import '../../booking/screens/proof_upload_screen.dart';

import '../../consultation/screens/chat_screen.dart';

import '../../consultation/screens/consultation_screen.dart';

import '../../consultation/screens/consultant_profile_screen.dart';

import '../../consultation/screens/consultation_requests_screen.dart';

import '../../consultation/models/consultation_session.dart';

import '../../shop/screens/shop_screen.dart';

import '../../shop/screens/product_detail_screen.dart';

import '../../shop/screens/cart_screen.dart';

import '../../shop/screens/checkout_screen.dart';

import '../../admin/screens/admin_screen.dart';

import '../../admin/screens/admin_shell_screen.dart';

import '../../admin/screens/admin_packages_screen.dart';

import '../../admin/screens/admin_poojas_screen.dart';

import '../../admin/screens/admin_pandits_screen.dart';

import '../../admin/screens/admin_bookings_screen.dart';

import '../../admin/screens/admin_consultations_screen.dart';

import '../../admin/screens/admin_reports_screen.dart';

import '../../admin/screens/admin_users_screen.dart';

import '../../admin/screens/admin_products_screen.dart';

import '../../admin/screens/admin_statistics_screen.dart';

import '../../admin/screens/admin_offline_bookings_screen.dart';

import '../../admin/screens/admin_support_tickets_screen.dart';

import '../../pandit/screens/pandit_screen.dart';

import '../../account/screens/edit_profile_screen.dart';

import '../../account/screens/notifications_screen.dart';

import '../../shop/screens/orders_screen.dart';

import '../../pandit/screens/pandit_booking_detail_screen.dart';

import '../../special_poojas/screens/special_poojas_screen.dart';

import '../../special_poojas/screens/special_pooja_detail_screen.dart';

import '../../offline_booking/screens/offline_pandit_browsing_screen.dart';

import '../../offline_booking/screens/offline_pandit_profile_screen.dart';

import '../../offline_booking/screens/offline_booking_tracking_screen.dart';

import '../../account/screens/account_screen.dart';

import '../../support/screens/help_form_screen.dart';

import '../../models/role_enum.dart';

import '../../widgets/bottom_nav_shell.dart';



// ── Route path constants ───────────────────────────────────────────────────────

abstract class Routes {

  // Shell tabs

  static const home = '/home';

  static const packages = '/packages';

  static const specialPoojas = '/special';

  static const shop = '/shop';

  static const account = '/account';



  // Auth

  static const splash = '/';

  static const login = '/login';

  static const signup = '/signup';



  // Booking (modal / push routes, outside shell)

  static const bookingWizard = '/booking/wizard';

  static const bookingDetail = '/booking/:id';

  static const bookingUploadProof = '/booking/:id/upload-proof';



  // Consultation chat (modal)

  static const consultation = '/consultation';

  static const consultationChat = '/consultation/chat';

  static const consultationProfile = '/consultation/pandit/:id';

  static const consultationRequests = '/account/consultations';



  // Shop sub-routes

  static const productDetail = '/shop/product/:id';

  static const cart = '/shop/cart';

  static const checkout = '/shop/checkout';



  // Admin dedicated shell (root-level)

  static const adminShell = '/admin';



  // Admin sub-routes (nested under /account/admin, used as push targets)

  static const adminBase = '/account/admin';

  static const adminPoojas = '/account/admin/poojas';

  static const adminPackages = '/account/admin/packages';

  static const adminPandits = '/account/admin/pandits';

  static const adminBookings = '/account/admin/bookings';

  static const adminConsultations = '/account/admin/consultations';

  static const adminReports = '/account/admin/reports';

  static const adminStatistics = '/account/admin/statistics';

  static const adminUsers = '/account/admin/users';

  static const adminProducts = '/account/admin/products';

  static const adminOfflineBookings = '/account/admin/offline-bookings';

  static const adminSupportTickets = '/account/admin/support-tickets';



  // User sub-routes

  static const myBookings = '/account/bookings';

  static const editProfile = '/account/edit-profile';

  static const manageAddresses = '/account/addresses';

  static const notifications = '/account/notifications';

  static const help = '/account/help';

  static const orders = '/shop/orders';



  // Offline booking marketplace

  static const offlinePandits = '/offline-pandits';

  static const offlinePanditProfile = '/offline-pandits/:id';

  static const offlineBookings = '/account/offline-bookings';



  // Pandit area

  static const panditDashboard = '/pandit';

  static const panditBookingDetail = '/pandit/booking/:id';

}



// ── RouterNotifier ──────────────────────────────────────────────────────────

class RouterNotifier extends ChangeNotifier {

  RouterNotifier(this._ref) {

    _ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());

  }



  final Ref _ref;



  String? redirect(BuildContext context, GoRouterState state) {

    final authState = _ref.read(authProvider);

    final location = state.matchedLocation;



    final isOnAuth = location == Routes.login || location == Routes.signup;

    final isOnSplash = location == Routes.splash;



    switch (authState) {

      case AuthInitial() || AuthLoading():

        return isOnSplash ? null : Routes.splash;



      case AuthEmailConfirmationPending():

        return isOnAuth ? null : Routes.login;



      case AuthUnauthenticated() || AuthError():

        if (isOnAuth) return null;

        return Routes.login;



      case AuthAuthenticated(user: final user):

        if (isOnSplash || isOnAuth) {

          if (user.role == UserRole.pandit) return Routes.panditDashboard;

          if (user.role == UserRole.admin) return Routes.adminShell;

          return Routes.home;

        }



        // Pandit should only see the pandit interface (or edit their profile).

        if (user.role == UserRole.pandit &&

            !location.startsWith('/pandit') &&

            !location.startsWith('/consultation') &&

            !location.startsWith('/offline-pandits') &&

            location != Routes.editProfile &&

            location != Routes.notifications &&

            location != Routes.consultationRequests) {

          return Routes.panditDashboard;

        }



        // Admin should be in the admin shell; redirect if on regular user pages.

        if (user.role == UserRole.admin) {

          final isAdminPath = location.startsWith('/admin') ||

              location.startsWith('/account/admin') ||

              location.startsWith('/booking') ||

              location.startsWith('/consultation') ||

              location.startsWith('/pandit') ||

              location.startsWith('/offline-pandits') ||

              location == Routes.editProfile ||

              location == Routes.notifications ||

              location == Routes.myBookings ||

              location == Routes.offlineBookings;

          if (!isAdminPath) return Routes.adminShell;

        }



        // Block non-admin from admin routes

        if (location.startsWith('/account/admin') && user.role != UserRole.admin) {

          return Routes.account;

        }

        if (location.startsWith('/admin') && user.role != UserRole.admin) {

          return Routes.account;

        }

        // Block non-pandit from pandit routes (unless admin)

        if (location.startsWith('/pandit') &&

            user.role != UserRole.pandit &&

            user.role != UserRole.admin) {

          return Routes.account;

        }

        return null;

      default:

        return null;

    }

  }

}



// ── Bottom-nav destination config ────────────────────────────────────────────

const _navDestinations = [

  NavDestination(

    label: 'Home',

    icon: Icons.home_outlined,

    activeIcon: Icons.home,

    initialLocation: Routes.home,

  ),

  NavDestination(

    label: 'Poojas',

    icon: Icons.spa_outlined,

    activeIcon: Icons.spa,

    initialLocation: Routes.packages,

  ),

  NavDestination(

    label: 'Special',

    icon: Icons.auto_awesome_outlined,

    activeIcon: Icons.auto_awesome,

    initialLocation: Routes.specialPoojas,

  ),

  NavDestination(

    label: 'Shop',

    icon: Icons.shopping_bag_outlined,

    activeIcon: Icons.shopping_bag,

    initialLocation: Routes.shop,

  ),

  NavDestination(

    label: 'Account',

    icon: Icons.person_outline,

    activeIcon: Icons.person,

    initialLocation: Routes.account,

  ),

];



// ── Router Provider ────────────────────────────────────────────────────────────

final routerProvider = Provider<GoRouter>((ref) {

  final notifier = RouterNotifier(ref);



  return GoRouter(

    initialLocation: Routes.splash,

    debugLogDiagnostics: false,

    refreshListenable: notifier,

    redirect: notifier.redirect,

    routes: [

      // ── Splash ────────────────────────────────────────────────────────────

      GoRoute(

        path: Routes.splash,

        name: 'splash',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const _SplashPage(),

          transitionsBuilder: _fadeTransition,

        ),

      ),



      // ── Auth ──────────────────────────────────────────────────────────────

      GoRoute(

        path: Routes.login,

        name: 'login',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const ModernLoginScreen(),

          transitionsBuilder: _slideUpTransition,

        ),

      ),

      GoRoute(

        path: Routes.signup,

        name: 'signup',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const SignupScreen(),

          transitionsBuilder: _slideUpTransition,

        ),

      ),



      // ── Booking Wizard (modal, above shell) ───────────────────────────────

      GoRoute(

        path: Routes.bookingWizard,

        name: 'booking-wizard',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: BookingWizardScreen(

            preSelectedPackage: state.extra is PackageModel

                ? state.extra as PackageModel

                : null,

          ),

          transitionsBuilder: _slideUpTransition,

        ),

      ),



      // ── Booking Detail + Proof Upload ─────────────────────────────────────

      GoRoute(

        path: '/booking/:id',

        name: 'booking-detail',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: BookingDetailScreen(bookingId: state.pathParameters['id']!),

          transitionsBuilder: _slideRightTransition,

        ),

      ),

      GoRoute(

        path: '/booking/:id/upload-proof',

        name: 'booking-upload-proof',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: ProofUploadScreen(

            bookingId: state.pathParameters['id']!,

            panditId: (state.extra as Map?)?['panditId'] as String? ?? '',

            bookingTitle: (state.extra as Map?)?['title'] as String? ?? 'Service',

          ),

          transitionsBuilder: _slideUpTransition,

        ),

      ),



      // ── Consultation Chat (modal) ─────────────────────────────────────────

      GoRoute(

        path: Routes.consultation,

        name: 'consultation',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const ConsultationScreen(),

          transitionsBuilder: _slideRightTransition,

        ),

      ),

      GoRoute(

        path: Routes.consultationChat,

        name: 'consultation-chat',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: ChatScreen(session: state.extra as ConsultationSession),

          transitionsBuilder: _slideUpTransition,

        ),

      ),

      GoRoute(

        path: Routes.consultationProfile,

        name: 'consultation-profile',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: ConsultantProfileScreen(panditId: state.pathParameters['id']!),

          transitionsBuilder: _slideRightTransition,

        ),

      ),



      // ── Offline Pandit Marketplace ───────────────────────────────────────

      GoRoute(

        path: Routes.offlinePandits,

        name: 'offline-pandits',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const OfflinePanditBrowsingScreen(),

          transitionsBuilder: _slideRightTransition,

        ),

        routes: [

          GoRoute(

            path: ':id',

            name: 'offline-pandit-profile',

            pageBuilder: (_, state) => CustomTransitionPage(

              key: state.pageKey,

              child: OfflinePanditProfileScreen(

                panditId: state.pathParameters['id']!,

              ),

              transitionsBuilder: _slideRightTransition,

            ),

          ),

        ],

      ),



      // ── Admin shell (dedicated admin-only area) ──────────────────────────

      GoRoute(

        path: Routes.adminShell,

        name: 'admin-shell',

        builder: (_, _) => const AdminShellScreen(),

      ),



      // ── Pandit-only area (outside customer tab shell) ─────────────────────

      GoRoute(

        path: Routes.panditDashboard,

        name: 'pandit-dashboard',

        pageBuilder: (_, state) => CustomTransitionPage(

          key: state.pageKey,

          child: const PanditScreen(),

          transitionsBuilder: _slideRightTransition,

        ),

        routes: [

          GoRoute(

            path: 'booking/:id',

            name: 'pandit-booking-detail',

            pageBuilder: (_, state) => CustomTransitionPage(

              key: state.pageKey,

              child: PanditBookingDetailScreen(

                bookingId: state.pathParameters['id']!,

              ),

              transitionsBuilder: _slideRightTransition,

            ),

          ),

        ],

      ),



      // ── Main Shell: 5 Bottom-Tab Branches ─────────────────────────────────

      StatefulShellRoute.indexedStack(

        builder: (context, state, navigationShell) => BottomNavShell(

          navigationShell: navigationShell,

          destinations: _navDestinations,

        ),

        branches: [

          // ── Tab 1: Home ─────────────────────────────────────────────────

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.home,

              name: 'home',

              builder: (_, _) => const HomeScreen(),

            ),

          ]),



          // ── Tab 2: Pooja Packages ────────────────────────────────────────

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.packages,

              name: 'packages',

              builder: (_, _) => const PackagesScreen(),

              routes: [

                GoRoute(

                  path: ':id',

                  name: 'package-detail',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: PackageDetailScreen(

                      packageId: state.pathParameters['id']!,

                    ),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

              ],

            ),

          ]),



          // ── Tab 3: Special Poojas ────────────────────────────────────────

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.specialPoojas,

              name: 'special-poojas',

              builder: (_, _) => const SpecialPoojasScreen(),

              routes: [

                GoRoute(

                  path: ':id',

                  name: 'special-pooja-detail',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: SpecialPoojaDetailScreen(

                      poojaId: state.pathParameters['id']!,

                    ),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

              ],

            ),

          ]),



          // ── Tab 4: Shop ──────────────────────────────────────────────────

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.shop,

              name: 'shop',

              builder: (_, _) => const ShopScreen(),

              routes: [

                GoRoute(

                  path: 'product/:id',

                  name: 'product-detail',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: ProductDetailScreen(

                      productId: state.pathParameters['id']!,

                    ),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'cart',

                  name: 'cart',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const CartScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'checkout',

                  name: 'checkout',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const CheckoutScreen(),

                    transitionsBuilder: _slideUpTransition,

                  ),

                ),

                GoRoute(

                  path: 'orders',

                  name: 'orders',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const OrdersScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

              ],

            ),

          ]),



          // ── Tab 5: Account (role-adaptive) ──────────────────────────────

          StatefulShellBranch(routes: [

            GoRoute(

              path: Routes.account,

              name: 'account',

              builder: (_, _) => const AccountScreen(),

              routes: [

                // Admin sub-routes

                GoRoute(

                  path: 'admin',

                  name: 'admin',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const AdminScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                  routes: [

                    GoRoute(

                      path: 'poojas',

                      name: 'admin-poojas',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminPoojasScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'packages',

                      name: 'admin-packages',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminPackagesScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'pandits',

                      name: 'admin-pandits',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminPanditsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'bookings',

                      name: 'admin-bookings',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminBookingsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'consultations',

                      name: 'admin-consultations',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminConsultationsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'reports',

                      name: 'admin-reports',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminReportsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'statistics',

                      name: 'admin-statistics',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminStatisticsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'users',

                      name: 'admin-users',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminUsersScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'products',

                      name: 'admin-products',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminProductsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'offline-bookings',

                      name: 'admin-offline-bookings',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminOfflineBookingsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                    GoRoute(

                      path: 'support-tickets',

                      name: 'admin-support-tickets',

                      pageBuilder: (_, state) => CustomTransitionPage(

                        key: state.pageKey,

                        child: const AdminSupportTicketsScreen(),

                        transitionsBuilder: _slideRightTransition,

                      ),

                    ),

                  ],

                ),

                // My Bookings

                GoRoute(

                  path: 'bookings',

                  name: 'my-bookings',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const BookingScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'offline-bookings',

                  name: 'offline-bookings',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const OfflineBookingTrackingScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'consultations',

                  name: 'consultation-requests',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const ConsultationRequestsScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                // Edit profile

                GoRoute(

                  path: 'edit-profile',

                  name: 'edit-profile',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const EditProfileScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'addresses',

                  name: 'manage-addresses',

                  // Addresses are now part of Edit Profile — redirect there.

                  redirect: (_, _) => Routes.editProfile,

                ),

                GoRoute(

                  path: 'notifications',

                  name: 'notifications',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const NotificationsScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

                GoRoute(

                  path: 'help',

                  name: 'help',

                  pageBuilder: (_, state) => CustomTransitionPage(

                    key: state.pageKey,

                    child: const HelpFormScreen(),

                    transitionsBuilder: _slideRightTransition,

                  ),

                ),

              ],

            ),

          ]),

        ],

      ),

    ],



    errorBuilder: (context, state) => Scaffold(

      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(Icons.error_outline, size: 64, color: Colors.red),

            const SizedBox(height: 16),

            Text(

              'Page not found:\n${state.uri.path}',

              textAlign: TextAlign.center,

            ),

            const SizedBox(height: 16),

            ElevatedButton(

              onPressed: () => context.go(Routes.home),

              child: const Text('Go Home'),

            ),

          ],

        ),

      ),

    ),

  );

});



// ── Minimal splash widget ─────────────────────────────────────────────────────

class _SplashPage extends StatelessWidget {

  const _SplashPage();



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFFF6B35),

      body: Center(

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Container(

              width: 100,

              height: 100,

              decoration: BoxDecoration(

                color: Colors.white.withValues(alpha: 0.2),

                borderRadius: BorderRadius.circular(24),

              ),

              child: const Icon(

                Icons.self_improvement,

                size: 56,

                color: Colors.white,

              ),

            ),

            const SizedBox(height: 24),

            const Text(

              'Saral Pooja',

              style: TextStyle(

                fontSize: 28,

                fontWeight: FontWeight.bold,

                color: Colors.white,

                letterSpacing: 0.5,

              ),

            ),

            const SizedBox(height: 8),

            Text(

              'Your Spiritual Marketplace',

              style: TextStyle(

                fontSize: 15,

                color: Colors.white.withValues(alpha: 0.8),

              ),

            ),

            const SizedBox(height: 48),

            const CircularProgressIndicator(

              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),

              strokeWidth: 2,

            ),

          ],

        ),

      ),

    );

  }

}



// ── Page Transition Helpers ───────────────────────────────────────────────────

Widget _fadeTransition(

  BuildContext context,

  Animation<double> animation,

  Animation<double> secondaryAnimation,

  Widget child,

) =>

    FadeTransition(opacity: animation, child: child);



Widget _slideUpTransition(

  BuildContext context,

  Animation<double> animation,

  Animation<double> secondaryAnimation,

  Widget child,

) =>

    SlideTransition(

      position: Tween<Offset>(

        begin: const Offset(0, 1),

        end: Offset.zero,

      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),

      child: child,

    );



Widget _slideRightTransition(

  BuildContext context,

  Animation<double> animation,

  Animation<double> secondaryAnimation,

  Widget child,

) =>

    SlideTransition(

      position: Tween<Offset>(

        begin: const Offset(1, 0),

        end: Offset.zero,

      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),

      child: child,

    );

