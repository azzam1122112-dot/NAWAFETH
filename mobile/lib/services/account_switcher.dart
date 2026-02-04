import 'package:flutter/material.dart';

import '../services/app_snackbar.dart';
import '../services/role_controller.dart';
import '../utils/auth_guard.dart';
import '../widgets/account_switch_sheet.dart';

class AccountSwitcher {
  const AccountSwitcher._();

  static Future<void> show(BuildContext context) async {
    await RoleController.instance.refreshFromPrefs();

    final role = RoleController.instance.notifier.value;
    final current = role.isProvider ? AccountMode.provider : AccountMode.client;

    final AccountMode? target = await showModalBottomSheet<AccountMode>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: AccountSwitchSheet(
            current: current,
            providerEnabled: role.isProviderRegistered,
          ),
        );
      },
    );

    if (!context.mounted) return;
    if (target == null || target == current) return;

    if (target == AccountMode.client) {
      await _switchToClient(context);
      return;
    }

    await _switchToProvider(context);
  }

  static Future<void> _switchToClient(BuildContext context) async {
    AppSnackBar.success('جاري التبديل إلى حساب العميل...');
    await RoleController.instance.setProviderMode(false);
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
  }

  static Future<void> _switchToProvider(BuildContext context) async {
    if (!await checkFullClient(context)) return;

    try {
      await RoleController.instance.syncFromBackend();
      await RoleController.instance.refreshFromPrefs();
    } catch (_) {
      // best-effort
    }

    final role = RoleController.instance.notifier.value;
    if (!role.isProviderRegistered) {
      AppSnackBar.error('حسابك عميل فقط حالياً. سجّل كمقدم خدمة أولاً.');
      return;
    }

    AppSnackBar.success('جاري الانتقال إلى لوحة مقدم الخدمة...');
    await RoleController.instance.setProviderMode(true);
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/provider_dashboard', (r) => false);
  }
}
