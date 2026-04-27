// lib/auth/screens/modern_login_screen.dart
// Redesigned login screen for Saral Puja â€” inspired by Astrotalk & VAMA

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/demo_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Color constants
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
const _kGold = Color(0xFFFFB700);        // golden-yellow logo background
const _kSaffron = Color(0xFFFF6B35);     // saffron orange accents & buttons
const _kDark = Color(0xFF1A1A1A);
const _kHint = Color(0xFF9E9E9E);
const _kBorder = Color(0xFFE0E0E0);
const _kSurface = Color(0xFFF8F8F8);

class ModernLoginScreen extends ConsumerStatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  ConsumerState<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends ConsumerState<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showOtpField = false;
  bool _isEmailLogin = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() { _showOtpField = true; _isLoading = false; });
    _showSnackBar('OTP sent to +91 ${_phoneController.text}', isError: false);
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await ref.read(authProvider.notifier).login(
      email: 'user${_phoneController.text}@saralpuja.com',
      password: 'Demo@123',
    );
    setState(() => _isLoading = false);
  }

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnackBar(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 14)),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAuthLoading = authState is AuthLoading;
    final busy = _isLoading || isAuthLoading;

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthError) _showSnackBar(next.message, isError: true);
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    // â”€â”€ Logo â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: _kGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kGold.withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: _MandalaIcon(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // â”€â”€ App Name â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Text(
                      'Saral Puja',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: _kDark,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // â”€â”€ "Login or Sign Up" heading â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'Login or Sign Up',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _kDark,
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // â”€â”€ Method toggle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kBorder),
                        ),
                        child: Row(
                          children: [
                            _MethodTab(
                              label: 'Mobile',
                              icon: Icons.smartphone_rounded,
                              active: !_isEmailLogin,
                              onTap: () => setState(() {
                                _isEmailLogin = false;
                                _showOtpField = false;
                              }),
                            ),
                            _MethodTab(
                              label: 'Email',
                              icon: Icons.email_rounded,
                              active: _isEmailLogin,
                              onTap: () => setState(() {
                                _isEmailLogin = true;
                                _showOtpField = false;
                              }),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // â”€â”€ Input fields â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          // Mobile flow
                          if (!_isEmailLogin) ...[
                            _PhoneField(controller: _phoneController, enabled: !_showOtpField && !busy),
                            if (_showOtpField) ...[
                              const SizedBox(height: 16),
                              _OtpField(controller: _otpController, enabled: !busy),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: busy ? null : _continue,
                                  child: Text('Resend OTP',
                                    style: GoogleFonts.inter(color: _kSaffron, fontWeight: FontWeight.w600, fontSize: 13)),
                                ),
                              ),
                            ],
                          ],
                          // Email flow
                          if (_isEmailLogin) ...[
                            _EmailField(controller: _emailController, enabled: !busy),
                            const SizedBox(height: 14),
                            _PasswordField(controller: _passwordController, enabled: !busy),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _showSnackBar('Password reset coming soon!', isError: false),
                                child: Text('Forgot Password?',
                                  style: GoogleFonts.inter(color: _kSaffron, fontWeight: FontWeight.w600, fontSize: 13)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // â”€â”€ CONTINUE / VERIFY / LOGIN button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _ContinueButton(
                        label: _isEmailLogin
                          ? 'LOGIN'
                          : (_showOtpField ? 'VERIFY OTP' : 'CONTINUE'),
                        busy: busy,
                        onPressed: _isEmailLogin
                          ? _loginWithEmail
                          : (_showOtpField ? _verifyOtp : _continue),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // â”€â”€ OR divider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('or',
                              style: GoogleFonts.inter(fontSize: 13, color: _kHint, fontWeight: FontWeight.w500)),
                          ),
                          Expanded(child: Divider(color: Colors.grey.shade300)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // â”€â”€ Continue with Truecaller â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: _TruecallerButton(
                        busy: busy,
                        onPressed: () => _showSnackBar('Truecaller login coming soon!', isError: false),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // â”€â”€ Demo quick-login chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    if (DemoConfig.demoMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Text('QUICK LOGIN (Demo)',
                                  style: GoogleFonts.inter(fontSize: 11, color: _kHint, fontWeight: FontWeight.w600)),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ]),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: DemoConfig.demoAccounts.map((a) => ActionChip(
                                avatar: Text(a.icon),
                                label: Text(a.label, style: GoogleFonts.inter(fontSize: 12)),
                                backgroundColor: _kSurface,
                                onPressed: busy ? null : () {
                                  setState(() => _isEmailLogin = true);
                                  _emailController.text = a.email;
                                  _passwordController.text = a.password;
                                },
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // â”€â”€ Sign-up link â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 14, color: _kHint),
                        children: [
                          const TextSpan(text: "New here? "),
                          TextSpan(
                            text: 'Create account',
                            style: const TextStyle(color: _kSaffron, fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => context.push(Routes.signup),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // â”€â”€ Terms text â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 12, color: _kHint, height: 1.6),
                          children: [
                            const TextSpan(text: 'By signing up, you agree to our '),
                            TextSpan(
                              text: 'Terms of Use',
                              style: const TextStyle(color: _kSaffron, decoration: TextDecoration.underline),
                            ),
                            const TextSpan(text: ' & '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: const TextStyle(color: _kSaffron, decoration: TextDecoration.underline),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // â”€â”€ Trust badges â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _TrustBadge(icon: Icons.verified_user_rounded, label: '100%\nSafe & Secure'),
                          _TrustBadge(icon: Icons.free_breakfast_rounded, label: 'Free\nLive Sessions'),
                          _TrustBadge(icon: Icons.headset_mic_rounded, label: '24/7\nAvailable'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// Sub-widgets
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

/// Custom painted mandala / Om icon inside the golden circle logo.
class _MandalaIcon extends StatelessWidget {
  const _MandalaIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(70, 70),
      painter: _MandalaPainter(),
    );
  }
}

class _MandalaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = _kDark
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Outer circle
    canvas.drawCircle(Offset(cx, cy), cx * 0.88, paint);

    // Inner sun circle
    canvas.drawCircle(Offset(cx, cy), cx * 0.38, paint);

    // Dot at center
    canvas.drawCircle(Offset(cx, cy), 3, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;

    // Orbit ring (tilted ellipse)
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(0.4);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: cx * 1.4, height: cx * 0.7),
      paint,
    );
    canvas.restore();

    // Dots on orbit
    const dotR = 4.0;
    final positions = [
      Offset(cx + cx * 0.62, cy - cx * 0.15),
      Offset(cx - cx * 0.62, cy + cx * 0.15),
    ];
    for (final p in positions) {
      canvas.drawCircle(p, dotR, paint..style = PaintingStyle.fill);
    }
    paint.style = PaintingStyle.stroke;

    // Rays around outer circle
    for (var i = 0; i < 8; i++) {
      final angle = i * 3.14159 / 4;
      final r1 = cx * 0.90;
      final r2 = cx * 1.05;
      canvas.drawLine(
        Offset(cx + r1 * _cos(angle), cy + r1 * _sin(angle)),
        Offset(cx + r2 * _cos(angle), cy + r2 * _sin(angle)),
        paint,
      );
    }
  }

  static double _cos(double a) => (a == 0 ? 1 : (a == 1.5708 ? 0 : (a == 3.14159 ? -1 : (a == 4.71239 ? 0 : (a < 1.5708 ? 1 - a * a / 2 : -1 + (3.14159 - a) * (3.14159 - a) / 2)))));
  static double _sin(double a) => _cos(a - 1.5708);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// â”€â”€ Method tab (Mobile / Email toggle) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _MethodTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _MethodTab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: active ? _kSaffron : _kHint),
              const SizedBox(width: 6),
              Text(label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? _kDark : _kHint,
                )),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Phone field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _PhoneField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        children: [
          // Flag + code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: _kBorder)),
            ),
            child: Row(
              children: [
                Text('+91',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: _kDark)),
              ],
            ),
          ),
          // Number
          Expanded(
            child: TextFormField(
              controller: controller,
              enabled: enabled,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 1),
              decoration: InputDecoration(
                hintText: 'Enter Mobile Number',
                hintStyle: GoogleFonts.inter(fontSize: 15, color: _kHint, fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                counterText: '',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mobile number is required';
                if (v.length != 10) return 'Enter valid 10-digit number';
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€ OTP field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _OtpField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 10),
        decoration: InputDecoration(
          hintText: '- - - - - -',
          hintStyle: GoogleFonts.inter(fontSize: 20, color: _kHint, letterSpacing: 8),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          counterText: '',
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          if (v == null || v.length != 6) return 'Enter 6-digit OTP';
          return null;
        },
      ),
    );
  }
}

// â”€â”€ Email field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _EmailField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Enter email address',
          hintStyle: GoogleFonts.inter(color: _kHint, fontSize: 15),
          prefixIcon: const Icon(Icons.email_outlined, color: _kHint, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Email is required';
          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) return 'Invalid email';
          return null;
        },
      ),
    );
  }
}

// â”€â”€ Password field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  const _PasswordField({required this.controller, required this.enabled});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,
        style: GoogleFonts.inter(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Enter password',
          hintStyle: GoogleFonts.inter(color: _kHint, fontSize: 15),
          prefixIcon: const Icon(Icons.lock_outline, color: _kHint, size: 20),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _kHint, size: 20),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Password is required';
          if (v.length < 6) return 'Min 6 characters';
          return null;
        },
      ),
    );
  }
}

// â”€â”€ CONTINUE button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ContinueButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _ContinueButton({required this.label, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kSaffron,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade200,
          disabledForegroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: busy
          ? const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Text(label,
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ),
    );
  }
}

// â”€â”€ Continue with Truecaller â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TruecallerButton extends ConsumerWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _TruecallerButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: busy ? null : () {
          ref.read(authProvider.notifier).continueAsGuest();
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline_rounded, color: _kHint, size: 22),
            const SizedBox(width: 10),
            Text('Continue as Guest',
              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kDark)),
          ],
        ),
      ),
    );
  }
}

// â”€â”€ Trust badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: _kGold.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _kSaffron, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            height: 1.4,
          )),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// End of file
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
