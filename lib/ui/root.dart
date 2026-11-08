import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/data_store.dart';
import '../state/nav_state.dart';
import '../state/session.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    switch (s.status) {
      case SessionStatus.starting:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case SessionStatus.signedOut:
        // Drop cached personal data whenever nobody is signed in.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          context.read<DataStore>().clear();
          context.read<NavState>().reset();
        });
        return const LoginScreen();
      case SessionStatus.signedIn:
        return const HomeShell();
    }
  }
}
