import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/auth_state.dart';
import '../../../core/providers/user_provider.dart';
import '../../../i18n/strings.g.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const _storage = FlutterSecureStorage();

  static final _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? '256522369666-joi6447bpg9h47pp5nrfhdjhbkghc03g.apps.googleusercontent.com' : null,
    serverClientId: kIsWeb ? null : '256522369666-joi6447bpg9h47pp5nrfhdjhbkghc03g.apps.googleusercontent.com',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = Translations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Icon(Icons.eco, size: 64, color: cs.primary),
                  const SizedBox(height: 8),
                  Text(
                    'PlateFlow',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.auth.login,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(160),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _passwordFocus.requestFocus(),
                          decoration: InputDecoration(
                            labelText: t.auth.email,
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) =>
                              v != null && v.contains('@')
                                  ? null
                                  : 'Enter valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordCtrl,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: t.auth.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) =>
                              (v?.length ?? 0) >= 6 ? null : 'Min 6 characters',
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _loading || _googleLoading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(t.auth.login,
                                    style: const TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('or',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurface.withAlpha(130))),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed:
                                _loading || _googleLoading ? null : _signInWithGoogle,
                            icon: _googleLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const GoogleLogo(),
                            label: const Text('Continue with Google',
                                style: TextStyle(fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(t.auth.noAccount),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/v1/auth/login', data: {
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });
      await _storage.write(
          key: 'access_token', value: res.data['access_token'] as String);
      await _storage.write(
          key: 'refresh_token', value: res.data['refresh_token'] as String);
      ref.read(authStateProvider).markLoggedIn();
      ref.invalidate(userProvider);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _errorMessage =
            detail is String ? detail : 'Invalid email or password.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      debugPrint('[Google] signIn returned: ${account?.email}');
      if (account == null) return; // User cancelled

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      debugPrint('[Google] idToken=${idToken != null} accessToken=${accessToken != null}');
      if (idToken == null && accessToken == null) {
        debugPrint('[Google] Both idToken and accessToken are null');
        setState(() => _errorMessage = 'Google sign-in failed. Try again.');
        return;
      }

      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/v1/auth/google', data: {
        if (idToken != null) 'id_token': idToken,
        if (idToken == null && accessToken != null) 'access_token': accessToken,
      });
      await _storage.write(
          key: 'access_token', value: res.data['access_token'] as String);
      await _storage.write(
          key: 'refresh_token', value: res.data['refresh_token'] as String);
      ref.read(authStateProvider).markLoggedIn();
      ref.invalidate(userProvider);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _errorMessage = detail is String ? detail : 'Google sign-in failed.';
      });
    } catch (e) {
      debugPrint('[Google] Exception: $e');
      setState(() => _errorMessage = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}

class GoogleLogo extends StatelessWidget {
  const GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Blue arc (top-right)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -1.4, 2.5, true, paint);

    // Red arc (top-left)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        -2.8, 1.4, true, paint);

    // Yellow arc (bottom-left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        2.0, 1.15, true, paint);

    // Green arc (bottom-right)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        1.1, 0.9, true, paint);

    // White center
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, paint);

    // Blue right bar
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - radius * 0.22,
          radius, radius * 0.44),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
