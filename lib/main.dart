import 'package:flutter/material.dart';

import 'app_data.dart';
import 'error_report.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorReport.install();
  runApp(const CollectearApp());
}

class CollectearApp extends StatefulWidget {
  const CollectearApp({super.key});

  @override
  State<CollectearApp> createState() => _CollectearAppState();
}

class _CollectearAppState extends State<CollectearApp> {
  late final Future<AppData> _data = AppData.load();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Collectear',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => ErrorBanner(child: child ?? const SizedBox.shrink()),
      home: FutureBuilder<AppData>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Erreur de chargement : ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return HomeShell(data: snap.data!);
        },
      ),
    );
  }
}
