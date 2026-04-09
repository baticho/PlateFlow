import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../core/api/api_client.dart';
import 'login_screen.dart' show GoogleLogo;

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _language = 'en';
  String _unitSystem = 'metric';
  String? _errorMessage;

  static const _storage = FlutterSecureStorage();

  static final _googleSignIn = GoogleSignIn(
    serverClientId:
        '256522369666-iro5qm9c5tjjf0c959stteca0s721fd3.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        setState(() => _errorMessage = 'Google sign-in failed. Try again.');
        return;
      }

      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/v1/auth/google', data: {
        'id_token': idToken,
        'preferred_language': _language,
        'preferred_unit_system': _unitSystem,
      });
      await _storage.write(
          key: 'access_token', value: res.data['access_token'] as String);
      await _storage.write(
          key: 'refresh_token', value: res.data['refresh_token'] as String);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _errorMessage = detail is String ? detail : 'Google sign-in failed.';
      });
    } catch (_) {
      setState(() => _errorMessage = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/v1/auth/register', data: {
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'full_name': _nameCtrl.text.trim(),
        'preferred_language': _language,
        'preferred_unit_system': _unitSystem,
      });
      await _storage.write(key: 'access_token', value: res.data['access_token'] as String);
      await _storage.write(key: 'refresh_token', value: res.data['refresh_token'] as String);
      if (mounted) context.go('/home');
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'];
      setState(() {
        _errorMessage = detail is String ? detail : 'Registration failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.eco, size: 48, color: cs.primary),
                    const SizedBox(height: 8),
                    Text(
                      'Join PlateFlow',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          (v?.trim().isNotEmpty ?? false) ? null : 'Enter your name',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Enter valid email',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordCtrl,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) =>
                          (v?.length ?? 0) >= 6 ? null : 'Min 6 characters',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _register(),
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      validator: (v) =>
                          v == _passwordCtrl.text ? null : 'Passwords do not match',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _language,
                      decoration: const InputDecoration(
                        labelText: 'Language',
                        prefixIcon: Icon(Icons.language_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'bg', child: Text('Български')),
                      ],
                      onChanged: (v) => setState(() => _language = v!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _unitSystem,
                      decoration: const InputDecoration(
                        labelText: 'Unit System',
                        prefixIcon: Icon(Icons.straighten_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'metric', child: Text('Metric (g, ml, kg)')),
                        DropdownMenuItem(
                            value: 'imperial',
                            child: Text('Imperial (oz, fl oz, lb)')),
                      ],
                      onChanged: (v) => setState(() => _unitSystem = v!),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading || _googleLoading ? null : _register,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Create Account',
                              style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const GoogleLogo(),
                        label: const Text('Continue with Google',
                            style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Already have an account? Sign In'),
                    ),
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
