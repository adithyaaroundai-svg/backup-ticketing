import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSignupEmailVerifyPage extends StatefulWidget {
  const AdminSignupEmailVerifyPage({super.key});

  @override
  State<AdminSignupEmailVerifyPage> createState() =>
      _AdminSignupEmailVerifyPageState();
}

class _AdminSignupEmailVerifyPageState
    extends State<AdminSignupEmailVerifyPage> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _fetchAllowedAdminEmail() async {
    final client = Supabase.instance.client;

    const keysToTry = [
      'admin_signup_email',
      'allowed_admin_email',
      'admin_email',
    ];

    String? extractEmail(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        final e = value.trim();
        return e.isEmpty ? null : e;
      }
      if (value is Map) {
        final direct = value['email'];
        final enabledEmail = value['enabled_email'];
        final nested = value['value'];

        final d = extractEmail(direct);
        if (d != null) return d;
        final ee = extractEmail(enabledEmail);
        if (ee != null) return ee;
        final n = extractEmail(nested);
        if (n != null) return n;

        final enabled = value['enabled'];
        if (enabled is bool && enabled == false) return null;

        for (final v in value.values) {
          final maybe = extractEmail(v);
          if (maybe != null) return maybe;
        }
      }
      return null;
    }

    for (final key in keysToTry) {
      final row = await client
          .from('app_settings')
          .select('setting_value')
          .eq('setting_key', key)
          .maybeSingle();

      if (row == null) continue;

      final value = row['setting_value'];
      final email = extractEmail(value);
      if (email != null) return email;
    }

    return null;
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final allowedEmail = await _fetchAllowedAdminEmail();

      if (!mounted) return;

      if (allowedEmail == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Admin signup is not configured. Add app_settings row with setting_key=admin_signup_email and setting_value containing the allowed email.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final entered = _emailController.text.trim().toLowerCase();
      if (entered != allowedEmail.toLowerCase()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email not authorized for admin signup.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      context.go('/admin-signup/details', extra: {'email': entered});
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to read app_settings: ${e.message}. This is usually due to RLS/policy. Please allow SELECT for anon on app_settings.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify email: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Verify admin email',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Admin Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Please enter email';
                          if (!v.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go('/login'),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back to Login'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: FilledButton(
                                onPressed: _isLoading ? null : _verify,
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Next'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
