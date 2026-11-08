import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'core/api_client.dart';
import 'core/token_store.dart';
import 'push/push_service.dart';
import 'state/data_store.dart';
import 'state/nav_state.dart';
import 'state/session.dart';
import 'ui/root.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final api = ApiClient(baseUrl: AppConfig.apiUrl, store: SecureTokenStore(), schoolSlug: AppConfig.schoolSlug);
  final nav = NavState();
  late final Session session;
  final push = PushService(api, nav, isSignedIn: () => session.status == SessionStatus.signedIn);
  session = Session(api, push);
  final data = DataStore(api);
  push.onForegroundPush = data.onPushReceived;

  await push.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: nav),
    ],
    child: const SmartBellApp(),
  ));
  session.start();
}

class SmartBellApp extends StatelessWidget {
  const SmartBellApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SmartBell',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const Root(),
      );
}
