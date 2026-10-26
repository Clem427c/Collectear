import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';

/// Dessine uniquement les cases visibles du terrain infini.
class TerrainComponent extends Component with HasGameReference<CollectearGame> {
  TerrainComponent() : super(priority: -100);

  static const _levelColors = [
    Color(0xFF8FD18A), // 0 plaine
    Color(0xFF6DBB72), // 1 colline
    Color(0xFF4E9F5D), // 2 plateau
    Color(0xFF9C8B78), // 3 roche
    Color(0xFFE6E4F0), // 4 sommet
  ];

  final _fills = [for (final c in _levelColors) Paint()..color = c];
  final _cliff = Paint()..color = const Color(0x66000000);
  final _sideEdge = Paint()..color = const Color(0x33000000);
  final _highlight = Paint()..color = const Color(0x22FFFFFF);
  final _gridDot = Paint()..color = const Color(0x14000000);

  @override
  void render(Canvas canvas) {
    final terrain = game.terrain;
    const t = GameConfig.tileSize;
    final rect = game.camera.visibleWorldRect.inflate(t);
    final x0 = (rect.left / t).floor();
    final x1 = (rect.right / t).ceil();
    final y0 = (rect.top / t).floor();
    final y1 = (rect.bottom / t).ceil();

    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        final level = terrain.levelAt(tx, ty);
        final left = tx * t;
        final top = ty * t;
        canvas.drawRect(Rect.fromLTWH(left, top, t + 0.5, t + 0.5), _fills[level]);
        if ((tx + ty).isEven) {
          canvas.drawRect(Rect.fromLTWH(left + t / 2 - 1, top + t / 2 - 1, 2, 2), _gridDot);
        }
        if (level > 0) {
          // Bord éclairé en haut, falaise sombre en bas si la case du dessous est plus basse.
          if (terrain.levelAt(tx, ty - 1) < level) {
            canvas.drawRect(Rect.fromLTWH(left, top, t, 3), _highlight);
          }
          final below = terrain.levelAt(tx, ty + 1);
          if (below < level) {
            final h = 5.0 + 3.0 * (level - below);
            canvas.drawRect(Rect.fromLTWH(left, top + t - h, t, h), _cliff);
          }
          if (terrain.levelAt(tx - 1, ty) < level) {
            canvas.drawRect(Rect.fromLTWH(left, top, 3, t), _sideEdge);
          }
          if (terrain.levelAt(tx + 1, ty) < level) {
            canvas.drawRect(Rect.fromLTWH(left + t - 3, top, 3, t), _sideEdge);
          }
        }
      }
    }
  }

  /// Utilisé par les entités pour connaître le niveau sous une position monde.
  static int levelUnder(Terrain terrain, Vector2 p) => terrain.levelAtWorld(p.x, p.y);
}
