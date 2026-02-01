import 'package:flutter/material.dart';

import 'client_orders_screen.dart';
import 'provider_dashboard/provider_orders_screen.dart';
import '../widgets/app_bar.dart';
import '../widgets/bottom_nav.dart';
import '../services/role_controller.dart';

class OrdersHubScreen extends StatelessWidget {
  const OrdersHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: CustomAppBar(showSearchField: false, title: 'طلباتي'),
        ),
        bottomNavigationBar: const CustomBottomNav(currentIndex: 1),
        body: ValueListenableBuilder<RoleState>(
          valueListenable: RoleController.instance.notifier,
          builder: (context, role, _) {
            if (role.isProvider) {
              return const ProviderOrdersScreen(embedded: true);
            }
            return const ClientOrdersScreen(embedded: true);
          },
        ),
      ),
    );
  }
}
