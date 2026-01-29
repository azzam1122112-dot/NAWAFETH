import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/account_api.dart';
import 'services/auth_api.dart';
import 'services/marketplace_api.dart';
import 'services/providers_api.dart';
import 'services/session_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  const phone = String.fromEnvironment('SMOKE_PHONE', defaultValue: '');
  const code = String.fromEnvironment('SMOKE_CODE', defaultValue: '1234');

  debugPrint('--- NAWAFETH SMOKE ---');
  debugPrint('API_BASE_URL=$baseUrl');

  if (phone.trim().isEmpty) {
    debugPrint('SMOKE_PHONE is missing. Run with: --dart-define=SMOKE_PHONE=+9665...');
    runApp(const SizedBox.shrink());
    return;
  }

  final storage = const SessionStorage();
  await storage.clear();

  try {
    // 1) OTP send
    debugPrint('[1/6] otp/send ...');
    final devCode = await AuthApi().sendOtp(phone: phone);
    debugPrint('otp/send OK (dev_code=${devCode ?? '-'})');

    // 2) OTP verify
    debugPrint('[2/6] otp/verify ...');
    final verify = await AuthApi().verifyOtp(phone: phone, code: code);
    await storage.saveTokens(access: verify.access, refresh: verify.refresh);
    await storage.savePhone(phone);
    debugPrint('otp/verify OK (needs_completion=${verify.needsCompletion}, is_new_user=${verify.isNewUser})');

    // 3) me
    debugPrint('[3/6] me ...');
    final me1 = await AccountApi().me(accessToken: verify.access);
    debugPrint('me OK (id=${me1['id']}, phone=${me1['phone']})');

    // 4) Force 401 by corrupting access token then call /me again.
    debugPrint('[4/6] force 401 then auto-refresh ...');
    await storage.saveTokens(access: 'invalid_access_token', refresh: verify.refresh);
    final me2 = await AccountApi().me(accessToken: 'invalid_access_token');
    debugPrint('auto-refresh OK (id=${me2['id']}, phone=${me2['phone']})');

    // 5) Providers GET (public)
    debugPrint('[5/6] providers/categories ...');
    final cats = await ProvidersApi().getCategories();
    debugPrint('providers/categories OK (count=${cats.length})');

    // 6) Marketplace GET (auth)
    debugPrint('[6/6] marketplace/client/requests ...');
    final myReq = await MarketplaceApi().getMyRequests();
    debugPrint('marketplace/client/requests OK (count=${myReq.length})');

    debugPrint('--- SMOKE PASSED ---');
  } catch (e, st) {
    debugPrint('--- SMOKE FAILED ---');
    debugPrint(e.toString());
    debugPrint(st.toString());
  }

  runApp(const SizedBox.shrink());

  // Best-effort exit (Android).
  await Future<void>.delayed(const Duration(milliseconds: 300));
  try {
    await SystemNavigator.pop();
  } catch (_) {
    // no-op
  }
}
