import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/demo_config.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../models/auth_state.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnackBar('Enter your email first, then tap "Forgot Password".',
          isError: false);
      return;
    }
    await ref.read(authProvider.notifier).sendPasswordReset(email);
    if (mounted) {
      _showSnackBar('Password reset email sent to $email.', isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthError) _showSnackBar(next.message, isError: true);
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Full-screen background image ──────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/image1.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Cinematic dual-gradient overlay ──────────────────────────
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.25, 0.52, 1.0],
                  colors: [
                    Color(0xCC000000),
                    Color(0x22000000),
                    Color(0xDD180A00),
                    Color(0xF8180A00),
                  ],
                ),
              ),
            ),
          ),

          // ── Decorative gold shimmer at top ────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 3,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.gold,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main scrollable content ───────────────────────────────────
          SafeArea(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  children: [
                      // ── Hero Brand Area ──────────────────────────────
                      Padding(
                        padding: const EdgeInsets.only(top: 36, bottom: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Diya • OM • Diya
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('🪔',
                                    style: TextStyle(fontSize: 26)),
                                const SizedBox(width: 18),
                                Text(
                                  'ॐ',
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.gold,
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                const Text('🪔',
                                    style: TextStyle(fontSize: 26)),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Logo with multi-layer golden glow
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(26),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.gold.withValues(alpha: 0.65),
                                    blurRadius: 36,
                                    spreadRadius: 6,
                                  ),
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.45),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: Image.asset(
                                  'assets/images/image15.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // App name in Playfair Display
                            Text(
                              AppStrings.appName,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 5),

                            // Hindi tagline
                            Text(
                              'आपकी पूजा, सरल बनाएं  •  Your Pooja, Simplified',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: AppColors.gold.withValues(alpha: 0.88),
                                fontSize: 11.5,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Glass Form Card ──────────────────────────────
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(38),
                          topRight: Radius.circular(38),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xF8FFFBF5),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(38),
                                topRight: Radius.circular(38),
                              ),
                            ),
                            child: Column(
                              children: [
                                // Gold handle bar
                                const SizedBox(height: 12),
                                Container(
                                  width: 44,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppColors.gold.withValues(alpha: 0.3),
                                      AppColors.gold.withValues(alpha: 0.7),
                                      AppColors.gold.withValues(alpha: 0.3),
                                    ]),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 28),

                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      24, 0, 24, 40),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Heading
                                        Text(
                                          'Welcome Back 🙏',
                                          style: GoogleFonts.playfairDisplay(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Sign in to continue your spiritual journey',
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 28),

                                        // Email field
                                        _GoldField(
                                          controller: _emailController,
                                          focusNode: _emailFocus,
                                          label: 'Email Address',
                                          hint: 'you@example.com',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction:
                                              TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email
                                          ],
                                          validator: (v) {
                                            if (v == null ||
                                                v.trim().isEmpty) {
                                              return 'Email is required.';
                                            }
                                            if (!RegExp(
                                                    r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                                .hasMatch(v.trim())) {
                                              return 'Enter a valid email address.';
                                            }
                                            return null;
                                          },
                                          onFieldSubmitted: (_) =>
                                              _passwordFocus.requestFocus(),
                                        ),
                                        const SizedBox(height: 16),

                                        // Password field
                                        _GoldField(
                                          controller: _passwordController,
                                          focusNode: _passwordFocus,
                                          label: 'Password',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          textInputAction:
                                              TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password
                                          ],
                                          validator: (v) {
                                            if (v == null || v.isEmpty) {
                                              return 'Password is required.';
                                            }
                                            if (v.length < 6) {
                                              return 'Password must be at least 6 characters.';
                                            }
                                            return null;
                                          },
                                          onFieldSubmitted: (_) => _submit(),
                                        ),

                                        // Forgot password
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: isLoading
                                                ? null
                                                : _handleForgotPassword,
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 6),
                                            ),
                                            child: Text(
                                              'Forgot Password?',
                                              style: GoogleFonts.inter(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Gradient Sign In button
                                        _GradientSignInButton(
                                          isLoading: isLoading,
                                          onPressed: _submit,
                                        ),
                                        const SizedBox(height: 12),

                                        // Continue as Guest
                                        OutlinedButton.icon(
                                          onPressed: isLoading
                                              ? null
                                              : () => ref
                                                  .read(authProvider.notifier)
                                                  .continueAsGuest(),
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size(
                                                double.infinity, 52),
                                            side: BorderSide(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.45)),
                                            foregroundColor: AppColors.primary,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                          ),
                                          icon: const Icon(
                                              Icons.person_outline,
                                              size: 18),
                                          label: Text(
                                            AppStrings.continueAsGuest,
                                            style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600),
                                          ),
                                        ),

                                        // Demo chips
                                        if (DemoConfig.demoMode) ...[
                                          const SizedBox(height: 30),
                                          _DemoDivider(),
                                          const SizedBox(height: 14),
                                          _DemoChipsRow(
                                              isLoading: isLoading,
                                              ref: ref),
                                        ],

                                        const SizedBox(height: 30),

                                        // OR divider
                                        Row(children: [
                                          Expanded(
                                              child: Divider(
                                                  color: AppColors.border
                                                      .withValues(alpha: 0.5))),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Text('OR',
                                                style: GoogleFonts.inter(
                                                    color: AppColors.textHint,
                                                    fontSize: 12)),
                                          ),
                                          Expanded(
                                              child: Divider(
                                                  color: AppColors.border
                                                      .withValues(alpha: 0.5))),
                                        ]),
                                        const SizedBox(height: 20),

                                        // Register link
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              AppStrings.dontHaveAccount,
                                              style: GoogleFonts.inter(
                                                  color:
                                                      AppColors.textSecondary,
                                                  fontSize: 14),
                                            ),
                                            GestureDetector(
                                              onTap: () => context
                                                  .push(Routes.signup),
                                              child: Text(
                                                AppStrings.register,
                                                style: GoogleFonts.inter(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Gold-Accented Text Field ──────────────────────────────────────────────────

class _GoldField extends StatefulWidget {
  const _GoldField({
    required this.controller,
    required this.label,
    required this.icon,
    this.focusNode,
    this.hint,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final FocusNode? focusNode;
  final String? hint;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<_GoldField> createState() => _GoldFieldState();
}

class _GoldFieldState extends State<_GoldField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword && _obscure,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onFieldSubmitted,
      style: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 15),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle:
            GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFFFF8F0),
        prefixIcon: Icon(widget.icon, size: 20, color: AppColors.primary),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0D5C5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

// ── Gradient Sign-In Button ───────────────────────────────────────────────────

class _GradientSignInButton extends StatelessWidget {
  const _GradientSignInButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: isLoading
              ? const LinearGradient(
                  colors: [Color(0xFFCCCCCC), Color(0xFFCCCCCC)])
              : const LinearGradient(
                  colors: [Color(0xFFD4611A), Color(0xFFBF9B30)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Demo Section Divider ──────────────────────────────────────────────────────

class _DemoDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 1,
          width: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.transparent,
              AppColors.gold.withValues(alpha: 0.6),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '✨  Quick Demo Login',
          style: GoogleFonts.inter(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0.6),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Demo Chips Row ────────────────────────────────────────────────────────────

class _DemoChipsRow extends StatelessWidget {
  const _DemoChipsRow({required this.isLoading, required this.ref});

  final bool isLoading;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: DemoConfig.demoAccounts.map((acct) {
        return GestureDetector(
          onTap: isLoading
              ? null
              : () => ref.read(authProvider.notifier).demoLogin(acct),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.gold.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(acct.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 7),
                Text(
                  acct.label,
                  style: GoogleFonts.inter(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
