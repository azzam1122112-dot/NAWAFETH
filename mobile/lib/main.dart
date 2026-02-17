import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

// 🟣 الشاشات الرئيسية
import 'screens/home_screen.dart';
import 'screens/my_chats_screen.dart';
import 'screens/chat_detail_screen.dart';
import 'screens/interactive_screen.dart';
import 'screens/my_profile_screen.dart';
import 'screens/add_service_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/provider_dashboard/provider_home_screen.dart';

// 🟢 الشاشات الجديدة
import 'screens/login_screen.dart';
import 'screens/search_provider_screen.dart';
import 'screens/urgent_request_screen.dart';
import 'screens/request_quote_screen.dart';
import 'screens/orders_hub_screen.dart';

// 🆕 شاشة الترحيب (Onboarding)
import 'screens/onboarding_screen.dart';
import 'screens/entry_screen.dart';

import 'services/app_snackbar.dart';
import 'services/app_navigation.dart';
import 'services/fcm_notification_service.dart';
import 'services/notifications_badge_controller.dart';
import 'services/role_controller.dart';

/// 🌙 وحدة تحكم للثيم واللغة
class MyThemeController extends InheritedWidget {
  final void Function(ThemeMode) changeTheme;
  final void Function(Locale) changeLanguage;
  final ThemeMode themeMode;
  final Locale locale;

  const MyThemeController({
    super.key,
    required this.changeTheme,
    required this.themeMode,
    required this.changeLanguage,
    required this.locale,
    required super.child,
  });

  static MyThemeController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MyThemeController>();

  @override
  bool updateShouldNotify(MyThemeController oldWidget) =>
      oldWidget.themeMode != themeMode || oldWidget.locale != locale;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  await RoleController.instance.initialize();
  await FcmNotificationService.instance.initialize();
  NotificationsBadgeController.instance.initialize();
  runApp(const NawafethApp());
}

class NawafethApp extends StatefulWidget {
  const NawafethApp({super.key});

  @override
  State<NawafethApp> createState() => _NawafethAppState();
}

class _NawafethAppState extends State<NawafethApp> {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar', 'SA'); // ✅ اللغة الافتراضية العربية

  /// 🔄 تبديل الثيم
  void _changeTheme(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
  }

  /// 🔄 تبديل اللغة
  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MyThemeController(
      changeTheme: _changeTheme,
      themeMode: _themeMode,
      changeLanguage: _changeLanguage,
      locale: _locale,
      child: MaterialApp(
        title: 'Nawafeth App',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        scaffoldMessengerKey: rootScaffoldMessengerKey,

        // ✅ إعدادات الثيم
        themeMode: _themeMode,
        theme: ThemeData(
          brightness: Brightness.light,
          fontFamily: 'Cairo',
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Cairo',
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black87,
            foregroundColor: Colors.white,
          ),
        ),

        // ✅ دعم تعدد اللغات
        locale: _locale,
        supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        onGenerateRoute: (settings) {
          if (settings.name == '/chats') {
            final args = settings.arguments;
            if (args is Map) {
              final requestId = _asInt(args['requestId']);
              final threadId = _asInt(args['threadId']);
              final name = (args['name'] ?? '').toString().trim();
              final isOnline = args['isOnline'] == true;
              final requestCode = (args['requestCode'] ?? '').toString().trim();
              final requestTitle = (args['requestTitle'] ?? '')
                  .toString()
                  .trim();
              if (requestId != null || threadId != null) {
                return MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    name: name.isEmpty ? 'محادثة الطلب' : name,
                    isOnline: isOnline,
                    requestId: requestId,
                    threadId: threadId,
                    requestCode: requestCode.isEmpty ? null : requestCode,
                    requestTitle: requestTitle.isEmpty ? null : requestTitle,
                  ),
                );
              }
            }
            return MaterialPageRoute(builder: (_) => const MyChatsScreen());
          }
          return null;
        },

        // ✅ المسارات
        initialRoute: '/home', // بدء التطبيق مباشرة من الصفحة الرئيسية
        routes: {
          '/entry': (context) => const EntryScreen(),
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) => const HomeScreen(),
          '/orders': (context) => const OrdersHubScreen(),
          '/interactive': (context) => ValueListenableBuilder<RoleState>(
            valueListenable: RoleController.instance.notifier,
            builder: (context, role, _) {
              return InteractiveScreen(
                mode: role.isProvider
                    ? InteractiveMode.provider
                    : InteractiveMode.client,
              );
            },
          ),
          '/profile': (context) => const MyProfileScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/add_service': (context) => const AddServiceScreen(),

          // Provider dashboard (separate from bottom-nav core screens)
          '/provider_dashboard': (context) => const ProviderHomeScreen(),

          // ✅ الشاشات الجديدة
          '/login': (context) => const LoginScreen(),
          '/search_provider': (context) => const SearchProviderScreen(),
          '/urgent_request': (context) => const UrgentRequestScreen(),
          '/request_quote': (context) => const RequestQuoteScreen(),
        },
      ),
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '').toString());
  }
}
