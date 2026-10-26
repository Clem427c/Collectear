import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/cards.dart';
import 'core/collection.dart';
import 'ui/menu_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CollectearApp());
}

class AppData {
  const AppData(this.pool, this.collection);
  final CardPool pool;
  final Collection collection;

  static Future<AppData> load() async {
    final json = await rootBundle.loadString('assets/data/cards.json');
    final pool = CardPool.fromJsonString(json);
    final collection = await Collection.load();
    return AppData(pool, collection);
  }
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
      home: FutureBuilder<AppData>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('Erreur de chargement : ${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return MenuScreen(data: snap.data!);
        },
      ),
    );
  }
}
