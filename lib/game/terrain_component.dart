import 'dart:ui';

import 'package:flame/components.dart';

import '../core/config.dart';
import '../core/decor.dart';
import '../core/terrain.dart';
import 'collectear_game.dart';
import 'decor_art.dart';

/// Dessine uniquement les cases visibles du terrain infini.
class TerrainComponent extends Component with HasGameReference<CollectearGame> {
  TerrainComponent() : super(priority: -100);

  // Plus c'est haut, plus c'est clair : vallée sombre → sommet enneigé.
  static const _levelColors = [
    Color(0xFF4F9A58), // 0 vallée
    Color(0xFF74BD6A), // 1 prairie
    Color(0xFF9BD57E), // 2 plateau
    Color(0xFFD9C79A), // 3 roche
    Color(0xFFF4F2FA), // 4 sommet
  ];

  final _fills = [for (final c in _levelColors) Paint()..color = c];

  // Textures de sol générées (une par étage) ; une image couvre 4×4 cases.
  static const _levelTextures = ['tile_l0_vallee', 'tile_l1_prairie', 'tile_l2_plateau', 'tile_l3_roche', 'tile_l4_sommet'];
  static const double _textureWorldSize = GameConfig.tileSize * 4;
  late final List<Paint?> _textures = [
    for (final t in _levelTextures) DecorArt.groundPaint(t, _textureWorldSize),
  ];
  late final Paint? _towerTexture = DecorArt.groundPaint('tile_tour', _textureWorldSize);
  // Voile par étage : assombrit les vallées, éclaircit les sommets (lisibilité des hauteurs).
  static const _levelShade = [Color(0x22000000), Color(0x00000000), Color(0x10FFFFFF), Color(0x1AFFFFFF), Color(0x00FFFFFF)];
  final _shade = Paint();
  final _propShadow = Paint()..color = const Color(0x40000000);

  // Tours : pierre taillée, plus claire vers le sommet.
  static const _towerColors = [
    Color(0xFF6F6890),
    Color(0xFF837BA6),
    Color(0xFF9890BA),
    Color(0xFFADA6CC),
    Color(0xFFC6C0E0),
  ];
  final _towerFills = [for (final c in _towerColors) Paint()..color = c];
  final _cliff = Paint()..color = const Color(0xFF3B2F45);
  final _sideEdge = Paint()..color = const Color(0x553B2F45);
  final _highlight = Paint()..color = const Color(0x55FFFFFF);
  final _gridDot = Paint()..color = const Color(0x14000000);

  /// Dessin de chaque chunk enregistré une fois (Picture), puis rejoué à chaque image.
  /// Avant, les ~400 cases visibles étaient recalculées et redessinées 60 fois par seconde.
  final Map<int, Picture> _chunks = {};
  static const int _maxCachedChunks = 80;

  static int _chunkKey(int cx, int cy) => ((cx & 0xFFFF) << 16) | (cy & 0xFFFF);

  Picture _chunkPicture(int cx, int cy) {
    final key = _chunkKey(cx, cy);
    final cached = _chunks[key];
    if (cached != null) return cached;
    if (_chunks.length >= _maxCachedChunks) {
      // Libère les chunks les plus loin du joueur.
      final p = game.player.position;
      final pcx = Terrain.chunkOf(Terrain.tileOf(p.x));
      final pcy = Terrain.chunkOf(Terrain.tileOf(p.y));
      final far = _chunks.keys.where((k) {
        final kx = (k >> 16).toSigned(16);
        final ky = (k & 0xFFFF).toSigned(16);
        return (kx - pcx).abs() > 3 || (ky - pcy).abs() > 3;
      }).toList();
      for (final k in far) {
        _chunks.remove(k)?.dispose();
      }
    }
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    const n = GameConfig.chunkTiles;
    for (var ty = cy * n; ty < (cy + 1) * n; ty++) {
      for (var tx = cx * n; tx < (cx + 1) * n; tx++) {
        _drawTile(canvas, tx, ty);
      }
    }
    // Décors (arbres, rochers, fleurs…) posés par-dessus, du fond vers l'avant.
    for (final prop in DecorRules.propsForChunk(game.terrain, game.seed, cx, cy)) {
      if (!DecorArt.has(prop.name)) continue;
      final foot = Offset((prop.tx + 0.5) * GameConfig.tileSize, (prop.ty + 0.85) * GameConfig.tileSize);
      final h = prop.height * GameConfig.tileSize;
      final w = h * 0.55;
      canvas.drawOval(Rect.fromCenter(center: foot, width: w, height: w * 0.32), _propShadow);
      DecorArt.drawOnGround(canvas, prop.name, foot, h, flipX: prop.flip);
    }
    final pic = recorder.endRecording();
    _chunks[key] = pic;
    return pic;
  }

  void _drawTile(Canvas canvas, int tx, int ty) {
    final terrain = game.terrain;
    const t = GameConfig.tileSize;
    final level = terrain.levelAt(tx, ty);
    final left = tx * t;
    final top = ty * t;
    final tower = terrain.towerRing(tx, ty) != null;
    final rect = Rect.fromLTWH(left, top, t + 0.5, t + 0.5);
    final texture = tower ? _towerTexture : _textures[level];
    if (texture != null) {
      canvas.drawRect(rect, texture);
      _shade.color = tower ? Color.fromARGB(18 * (GameConfig.maxLevel - level), 0, 0, 0) : _levelShade[level];
      if (_shade.color.a > 0) canvas.drawRect(rect, _shade);
    } else {
      canvas.drawRect(rect, tower ? _towerFills[level] : _fills[level]);
      if ((tx + ty).isEven) {
        canvas.drawRect(Rect.fromLTWH(left + t / 2 - 1, top + t / 2 - 1, 2, 2), _gridDot);
      }
    }
    if (level > 0) {
      // Bord éclairé en haut, falaise sombre en bas si la case du dessous est plus basse.
      if (terrain.levelAt(tx, ty - 1) < level) {
        canvas.drawRect(Rect.fromLTWH(left, top, t, 3), _highlight);
      }
      final below = terrain.levelAt(tx, ty + 1);
      if (below < level) {
        final h = 6.0 + 4.0 * (level - below);
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

  @override
  void render(Canvas canvas) {
    const t = GameConfig.tileSize;
    final rect = game.camera.visibleWorldRect.inflate(t);
    final cx0 = Terrain.chunkOf((rect.left / t).floor());
    final cx1 = Terrain.chunkOf((rect.right / t).ceil());
    final cy0 = Terrain.chunkOf((rect.top / t).floor());
    final cy1 = Terrain.chunkOf((rect.bottom / t).ceil());
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= cx1; cx++) {
        canvas.drawPicture(_chunkPicture(cx, cy));
      }
    }
  }

  @override
  void onRemove() {
    for (final p in _chunks.values) {
      p.dispose();
    }
    _chunks.clear();
    super.onRemove();
  }

  /// Utilisé par les entités pour connaître le niveau sous une position monde.
  static int levelUnder(Terrain terrain, Vector2 p) => terrain.levelAtWorld(p.x, p.y);
}
