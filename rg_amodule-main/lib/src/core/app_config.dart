class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.razorpayKeyId,
    required this.cloudflareUploadFunction,
    required this.clientDemoAccess,
  });

  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      razorpayKeyId: String.fromEnvironment('RAZORPAY_KEY_ID'),
      cloudflareUploadFunction: String.fromEnvironment(
        'CLOUDFLARE_UPLOAD_FUNCTION',
        defaultValue: 'cloudflare-r2-upload-url',
      ),
      clientDemoAccess: bool.fromEnvironment('CLIENT_DEMO_ACCESS'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String razorpayKeyId;
  final String cloudflareUploadFunction;
  final bool clientDemoAccess;

  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  bool get hasRazorpay => razorpayKeyId.startsWith('rzp_');
}
