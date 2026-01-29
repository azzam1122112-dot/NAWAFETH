import 'package:flutter/material.dart';

import 'core/network/api_dio.dart';
import 'services/account_api.dart';
import 'services/auth_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ApiTestApp());
}

class ApiTestApp extends StatelessWidget {
  const ApiTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ApiTestScreen(),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  static const phone = String.fromEnvironment('TEST_PHONE', defaultValue: '');
  static const code = String.fromEnvironment('TEST_CODE', defaultValue: '1234');

  final List<String> _lines = <String>[];
  bool _busy = false;

  void _log(String s) {
    setState(() {
      _lines.add(s);
    });
  }

  Future<void> _runFlow() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _lines.clear();
    });

    try {
      _log('API_BASE_URL=${ApiDio.baseUrl}');

      _log('1) health ...');
      final health = await ApiDio.dio.get<dynamic>('/health/');
      _log('health: ${health.data}');

      if (phone.trim().isEmpty) {
        _log('ERROR: TEST_PHONE is missing. Run with --dart-define=TEST_PHONE=+9665...');
        return;
      }

      _log('2) otp/send ...');
      final devCode = await AuthApi().otpSend(phone: phone);
      _log('otp/send OK (dev_code=${devCode ?? '-'})');

      _log('3) otp/verify ...');
      final verify = await AuthApi().otpVerify(phone: phone, code: code);
      _log('otp/verify OK (is_new_user=${verify.isNewUser}, needs_completion=${verify.needsCompletion})');

      _log('4) me ...');
      final me = await AccountApi().me();
      _log('me OK (id=${me['id']}, phone=${me['phone']})');

      _log('DONE ✅');
    } catch (e) {
      _log('FAILED ❌');
      _log(e.toString());
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _corruptAccessAndMe() async {
    if (_busy) return;
    setState(() {
      _busy = true;
    });

    try {
      final refresh = await AuthApi().getRefreshForDebug();
      if (refresh == null || refresh.trim().isEmpty) {
        _log('No refresh token saved; run the flow first.');
        return;
      }

      _log('Corrupting access token...');
      await ApiDio.setTokens('invalid_access_token', refresh);

      _log('Calling me() expecting auto-refresh ...');
      final me = await AccountApi().me();
      _log('auto-refresh OK ✅ (id=${me['id']}, phone=${me['phone']})');
    } catch (e) {
      _log('auto-refresh FAILED ❌');
      _log(e.toString());
    } finally {
      setState(() {
        _busy = false;
      });
    }
  }

  Future<void> _clearTokens() async {
    await ApiDio.clearTokens();
    _log('Tokens cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NAWAFETH API Test'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy ? null : _runFlow,
                  child: const Text('Run: health → otp → me'),
                ),
                ElevatedButton(
                  onPressed: _busy ? null : _corruptAccessAndMe,
                  child: const Text('Corrupt token → me (refresh)'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : _clearTokens,
                  child: const Text('Clear tokens'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _lines.length,
              itemBuilder: (context, index) {
                return Text(_lines[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
