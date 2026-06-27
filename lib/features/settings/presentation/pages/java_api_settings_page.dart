import 'package:flutter/material.dart';

import '../../../../core/sync/JavaAuthService.dart';
import '../../../../core/sync/java_api_config_service.dart';
import '../../../../core/theme/app_theme.dart';

class JavaApiSettingsPage extends StatefulWidget {
  const JavaApiSettingsPage({super.key});

  @override
  State<JavaApiSettingsPage> createState() => _JavaApiSettingsPageState();
}

class _JavaApiSettingsPageState extends State<JavaApiSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serverUrlCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await JavaApiConfigService.instance.loadConfig(
      defaultBaseUrl: JavaAuthService.defaultBaseUrl,
    );
    if (!mounted) return;
    setState(() {
      _serverUrlCtrl.text = config.baseUrl;
      _usernameCtrl.text = config.username;
      _passwordCtrl.text = config.password;
    });
  }

  Future<void> _save({required bool testLogin}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      if (testLogin) {
        _isTesting = true;
      } else {
        _isSaving = true;
      }
    });

    try {
      await JavaApiConfigService.instance.saveConfig(
        baseUrl: _serverUrlCtrl.text,
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
      );
      await JavaAuthService.instance.logout();

      if (testLogin) {
        await JavaAuthService.instance.ensureAuthenticated(forceRefresh: true);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            testLogin
                ? 'Backend login successful. Direct online mode is ready.'
                : 'Backend settings saved.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backend setup failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isTesting = false;
      });
    }
  }

  Future<void> _verifyConnection() async {
    setState(() => _isTesting = true);
    try {
      await JavaAuthService.instance.ensureAuthenticated(forceRefresh: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Backend connection verified.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection verification failed: $error'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backend API Settings')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Configure the backend server URL and your username/mobile login credentials.',
                style: AppTheme.caption,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _serverUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Server URL'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Server URL is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: 'Backend Username / Mobile Number'),
                validator: (value) =>
                    (value?.trim().isEmpty ?? true) ? 'Username or mobile number is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Backend Password'),
                validator: (value) =>
                    (value?.isEmpty ?? true) ? 'Password is required' : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Use the same username or mobile number mapped to your backend user.',
                style: AppTheme.caption,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_isSaving || _isTesting) ? null : () => _save(testLogin: false),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Settings'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (_isSaving || _isTesting) ? null : () => _save(testLogin: true),
                child: const Text('Test Login'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: (_isSaving || _isTesting) ? null : _verifyConnection,
                child: const Text('Verify Connection'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
