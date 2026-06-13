import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:velix_data/velix_data.dart';
import 'package:velix_design/velix_design.dart';

import '../../../di/providers.dart';
import '../../../router/app_router.dart';
import '../../components/velix_button.dart';

/// Alpha authentication screen.
///
/// Two tabs:
///   - Create account: pick a handle, generate a fresh device_secret, register.
///   - Sign in: enter your account_id + device_secret(b64), HMAC-challenge, submit.
///
/// On success: persists the session to disk. The user is told to fully
/// restart the app (cold-start picks up the session and wires the remote
/// repositories).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _registerHandleCtl = TextEditingController();
  final _loginAccountIdCtl = TextEditingController();
  final _loginSecretCtl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _tabs.dispose();
    _registerHandleCtl.dispose();
    _loginAccountIdCtl.dispose();
    _loginSecretCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return Scaffold(
      backgroundColor: v.colors.surface.substrate,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: v.space.gutterScreen),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: v.space.s9),
              Text('Velix Alpha', style: v.typography.titleL),
              SizedBox(height: v.space.s2),
              Text(
                'Local development build. State stored on this device.',
                style: v.typography.bodyS.copyWith(color: v.colors.text.secondary),
              ),
              SizedBox(height: v.space.s7),
              TabBar(
                controller: _tabs,
                tabs: const [
                  Tab(text: 'Create account'),
                  Tab(text: 'Sign in'),
                ],
                indicatorColor: v.colors.accent.signature,
              ),
              SizedBox(height: v.space.s5),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _RegisterPanel(
                      handleCtl: _registerHandleCtl,
                      busy: _busy,
                      error: _error,
                      onSubmit: _doRegister,
                    ),
                    _LoginPanel(
                      accountIdCtl: _loginAccountIdCtl,
                      secretCtl: _loginSecretCtl,
                      busy: _busy,
                      error: _error,
                      onSubmit: _doLogin,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doRegister(String handle) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final boot = ref.read(bootstrapProvider);
      final client = boot.alphaApiClient;
      final secret = AlphaApiClient.generateDeviceSecret();
      final result = await client.register(
        handle: handle,
        deviceSecret: secret,
      );
      final session = AlphaSession(
        accountId: result.accountId,
        handle: result.handle,
        token: result.token,
        identityPublicKey: List<int>.from(secret),
        identityPrivateKey: List<int>.from(secret),
      );
      await boot.sessionStore.save(session);
      if (!mounted) return;
      _showSecret(secret, session);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doLogin(String accountId, String secretB64) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final boot = ref.read(bootstrapProvider);
      final client = boot.alphaApiClient;
      final Uint8List secret;
      try {
        secret = base64.decode(secretB64);
      } catch (_) {
        throw const FormatException('device secret must be valid base64');
      }
      if (secret.length != 32) {
        throw const FormatException('device secret must decode to 32 bytes');
      }
      final nonce = await client.challenge(accountId: accountId);
      final result = await client.login(
        accountId: accountId,
        nonce: nonce,
        deviceSecret: secret,
      );
      final me = await client.me();
      final session = AlphaSession(
        accountId: me.accountId,
        handle: me.handle,
        token: result.token,
        identityPublicKey: List<int>.from(secret),
        identityPrivateKey: List<int>.from(secret),
      );
      await boot.sessionStore.save(session);
      if (!mounted) return;
      _showRestartHint();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSecret(Uint8List secret, AlphaSession session) {
    final v = context.velix;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: v.colors.surface.lifted,
        title: const Text('Save these to sign in on another device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Account ID:', style: v.typography.labelM),
              SelectableText(
                session.accountId,
                style: v.typography.bodyM.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Text('Device secret (base64):', style: v.typography.labelM),
              SelectableText(
                base64.encode(secret),
                style: v.typography.bodyM.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                'Alpha-grade. Store these â€” there is no recovery.',
                style: v.typography.bodyS.copyWith(color: v.colors.text.tertiary),
              ),
              const SizedBox(height: 8),
              Text(
                'Restart the app to enter the home screen with your session active.',
                style: v.typography.bodyS.copyWith(color: v.colors.text.secondary),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(Routes.home);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showRestartHint() {
    final v = context.velix;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: v.colors.surface.lifted,
        title: const Text('Signed in'),
        content: const Text(
          'Restart the app to enter the home screen with your session active.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(Routes.home);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _RegisterPanel extends StatelessWidget {
  const _RegisterPanel({
    required this.handleCtl,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController handleCtl;
  final bool busy;
  final String? error;
  final Future<void> Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: v.space.s5),
          Text(
            'Pick a handle. A device secret is generated on this device.',
            style: v.typography.bodyS.copyWith(color: v.colors.text.secondary),
          ),
          SizedBox(height: v.space.s5),
          TextField(
            controller: handleCtl,
            decoration: const InputDecoration(
              labelText: 'Handle',
              hintText: 'alice',
            ),
          ),
          if (error != null) ...[
            SizedBox(height: v.space.s4),
            Text(
              error!,
              style: v.typography.bodyS.copyWith(color: v.colors.semantic.danger),
            ),
          ],
          SizedBox(height: v.space.s7),
          VelixButton(
            label: busy ? 'Creatingâ€¦' : 'Create account',
            onPressed: busy ? null : () { onSubmit(handleCtl.text.trim()); },
          ),
        ],
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.accountIdCtl,
    required this.secretCtl,
    required this.busy,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController accountIdCtl;
  final TextEditingController secretCtl;
  final bool busy;
  final String? error;
  final Future<void> Function(String, String) onSubmit;

  @override
  Widget build(BuildContext context) {
    final v = context.velix;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: v.space.s5),
          TextField(
            controller: accountIdCtl,
            decoration: const InputDecoration(
              labelText: 'Account ID',
            ),
          ),
          SizedBox(height: v.space.s4),
          TextField(
            controller: secretCtl,
            decoration: const InputDecoration(
              labelText: 'Device secret (base64)',
            ),
            obscureText: true,
          ),
          if (error != null) ...[
            SizedBox(height: v.space.s4),
            Text(
              error!,
              style: v.typography.bodyS.copyWith(color: v.colors.semantic.danger),
            ),
          ],
          SizedBox(height: v.space.s7),
          VelixButton(
            label: busy ? 'Signing inâ€¦' : 'Sign in',
            onPressed: busy
                ? null
                : () {
                    onSubmit(
                      accountIdCtl.text.trim(),
                      secretCtl.text.trim(),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
