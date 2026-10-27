import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Décors générés par Clem (art/decors/raw → assets/images/decors, préparés en CI par
/// tool/process_decors.py). Si une image manque, le jeu garde ses dessins de secours.
class DecorArt {
  DecorArt._();

  static final Map<String, Image> _images = {};
  static bool _loaded = false;

  static Future<void> load(Images images) async {
    if (_loaded) return;
    _loaded = true;
    List<String> files;
    try {
      files = (jsonDecode(await rootBundle.loadString('assets/images/decors/manifest.json')) as List).cast<String>();
    } catch (_) {
      return; // pas de décors : dessins de secours
    }
    for (final f in files) {
      try {
        _images[f.replaceAll('.png', '')] = await images.load('decors/$f');
      } catch (_) {}
    }
  }

  static Image? get(String name) => _images[name];
  static bool has(String name) => _images.containsKey(name);

  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _tinted = Paint()..filterQuality = FilterQuality.medium;

  /// Dessine [name] posé au sol : bas de l'image sur [foot], hauteur [height] (unités du monde).
  /// Renvoie false si l'image n'existe pas (l'appelant dessine alors sa version de secours).
  static bool drawOnGround(Canvas canvas, String name, Offset foot, double height,
      {bool flipX = false, double opacity = 1, Color? flash}) {
    final img = _images[name];
    if (img == null) return false;
    final w = height * img.width / img.height;
    final dst = Rect.fromLTWH(foot.dx - w / 2, foot.dy - height, w, height);
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    Paint p = _paint;
    if (opacity < 1 || flash != null) {
      p = _tinted
        ..color = Color.fromRGBO(255, 255, 255, opacity.clamp(0.0, 1.0))
        ..colorFilter = flash != null ? ColorFilter.mode(flash, BlendMode.srcATop) : null;
    }
    if (flipX) {
      canvas.save();
      canvas.translate(foot.dx * 2, 0);
      canvas.scale(-1, 1);
      // dst est symétrique autour de foot.dx : une fois le canvas retourné, l'image tombe au même endroit.
      canvas.drawImageRect(img, src, dst, p);
      canvas.restore();
      return true;
    }
    canvas.drawImageRect(img, src, dst, p);
    return true;
  }

  /// Motif répété pour peindre le sol : l'image (512 px) couvre [worldSize] unités du monde.
  static Paint? groundPaint(String name, double worldSize) {
    final img = _images[name];
    if (img == null) return null;
    final s = worldSize / img.width;
    final m = Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]);
    return Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ImageShader(img, TileMode.repeated, TileMode.repeated, m);
  }
}
