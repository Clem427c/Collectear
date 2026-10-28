import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Erreurs techniques affichées à l'écran (bandeau rouge) au lieu de rester invisibles.
/// Retour de Clem du 28/10 : sur PC, une run restait figée sans aucun message ; avec ce bandeau,
/// une simple capture d'écran suffit pour trouver la cause.
class ErrorReport {
  ErrorReport._();

  static final ValueNotifier<String?> last = ValueNotifier(null);

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      _record(details.exceptionAsString(), details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _record('$error', stack);
      return true;
    };
  }

  static void _record(String message, StackTrace? stack) {
    final where = stack?.toString().split('\n').where((l) => l.contains('package:collectear')).take(2).join(' | ');
    last.value = where == null || where.isEmpty ? message : '$message\n$where';
    debugPrint('Erreur signalée : ${last.value}');
  }
}

/// Bandeau rouge en haut de l'écran quand une erreur technique survient (fermable).
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      child,
      ValueListenableBuilder<String?>(
        valueListenable: ErrorReport.last,
        builder: (context, err, _) => err == null
            ? const SizedBox.shrink()
            : Positioned(
                left: 8,
                right: 8,
                top: MediaQuery.of(context).padding.top + 4,
                child: Material(
                  color: const Color(0xEEB3261E),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 0, 6),
                    child: Row(children: [
                      Expanded(
                        child: Text('Erreur technique (fais une capture d\'écran) : $err',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => ErrorReport.last.value = null,
                        icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ]),
                  ),
                ),
              ),
      ),
    ]);
  }
}
