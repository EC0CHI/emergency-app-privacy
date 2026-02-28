import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/supabase_service.dart';
import 'services/onesignal_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1. Инициализация Supabase
    print('Initializing Supabase...');
    await SupabaseService.initialize();

    // 2. Инициализация OneSignal
    print('Initializing OneSignal...');
    await OneSignalService.initialize();
    OneSignalService.setupNotificationHandlers();

    // 3. Получаем userId (локально)
    print('Getting user ID...');
    final userId = await UserService.getUserId();
    print('User ID: $userId');

    // 4. Устанавливаем External User ID в OneSignal
    await OneSignalService.setExternalUserId(userId);

    // 5. Ждем OneSignal Player ID и сохраняем пользователя
    print('Waiting for OneSignal Player ID...');
    final playerId = await OneSignalService.waitForPlayerId();

    if (playerId != null) {
      print('Saving user to Supabase...');
      await SupabaseService.saveUser(userId, playerId);
      print('Setup complete!');
    } else {
      print('Warning: OneSignal Player ID not received, user not saved to cloud');
    }
  } catch (e) {
    print('Error during initialization: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = const Locale('ru');
  bool _isLoading = true;
  bool _hasUserName = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Загружает язык и проверяет наличие имени для роутинга (FR-07).
  /// Не обращается к Supabase / OneSignal — работает только с SharedPreferences,
  /// что позволяет тестировать MyApp без инициализации внешних сервисов.
  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language') ?? 'ru';
    final hasName = await UserService.hasUserName();
    if (mounted) {
      setState(() {
        _locale = Locale(languageCode);
        _hasUserName = hasName;
        _isLoading = false;
      });
    }
  }

  void _updateLocale(String languageCode) {
    setState(() {
      _locale = Locale(languageCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (_isLoading) {
      home = const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('welcome_loading_indicator'),
          ),
        ),
      );
    } else if (_hasUserName) {
      home = MainScreen(updateLocale: _updateLocale);
    } else {
      home = const WelcomeScreen();
    }

    return MaterialApp(
      title: 'Emergency Contacts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.grey,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      locale: _locale,
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
        Locale('zh'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: {
        '/main': (context) => MainScreen(updateLocale: _updateLocale),
        '/welcome': (context) => const WelcomeScreen(),
      },
      home: home,
    );
  }
}
