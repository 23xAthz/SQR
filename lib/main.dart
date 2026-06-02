// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sqrprojectatlabendsem/files/core/theme/app_theme.dart';
import 'package:sqrprojectatlabendsem/files/data/local/database_helper.dart';
import 'package:sqrprojectatlabendsem/files/presentation/screens/scanner_screen.dart';
import 'package:sqrprojectatlabendsem/files/presentation/screens/history_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize DB
  await DatabaseHelper.instance.database;

  runApp(const ProviderScope(child: SqrApp()));
}

class SqrApp extends StatelessWidget {
  const SqrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SQR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _RootShell(),
    );
  }
}

/// Bottom nav shell wrapping Scanner and History tabs
class _RootShell extends StatefulWidget {
  const _RootShell();

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  int _index = 0;

  static const _pages = [
    ScannerScreen(),
    HistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.surface,
        indicatorColor: AppTheme.accent.withOpacity(0.15),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner, color: AppTheme.accent),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppTheme.accent),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
