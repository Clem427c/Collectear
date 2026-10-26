/// Bruit procédural déterministe, identique sur mobile (VM) et web (JS).
///
/// Toutes les opérations restent sur 32 bits non signés pour éviter
/// les pertes de précision des entiers sur le web.
library;

const int _mask32 = 0xFFFFFFFF;

/// Multiplication 32 bits (équivalent de Math.imul, résultat non signé).
int imul32(int a, int b) {
  a &= _mask32;
  b &= _mask32;
  final lo = (a & 0xFFFF) * b;
  final hi = (((a >>> 16) * b) & 0xFFFF) << 16;
  return (lo + hi) & _mask32;
}

/// Hache trois entiers en un entier 32 bits non signé.
int hash3(int seed, int x, int y) {
  var h = (seed & _mask32) ^ 0x9E3779B9;
  h = imul32(h ^ (x & _mask32), 0x85EBCA6B);
  h = (h ^ (h >>> 13)) & _mask32;
  h = imul32(h ^ (y & _mask32), 0xC2B2AE35);
  h = (h ^ (h >>> 16)) & _mask32;
  h = imul32(h, 0x27D4EB2F);
  h = (h ^ (h >>> 15)) & _mask32;
  return h;
}

/// Valeur pseudo-aléatoire dans [0, 1).
double hash01(int seed, int x, int y) => hash3(seed, x, y) / 4294967296.0;

double _smooth(double t) => t * t * (3 - 2 * t);

/// Bruit de valeur 2D interpolé, dans [0, 1).
double valueNoise(int seed, double x, double y) {
  final x0 = x.floor();
  final y0 = y.floor();
  final fx = _smooth(x - x0);
  final fy = _smooth(y - y0);
  final a = hash01(seed, x0, y0);
  final b = hash01(seed, x0 + 1, y0);
  final c = hash01(seed, x0, y0 + 1);
  final d = hash01(seed, x0 + 1, y0 + 1);
  final top = a + (b - a) * fx;
  final bottom = c + (d - c) * fx;
  return top + (bottom - top) * fy;
}

/// Bruit fractal (plusieurs octaves), normalisé dans [0, 1).
double fbm(int seed, double x, double y, {int octaves = 3}) {
  var sum = 0.0;
  var amp = 1.0;
  var freq = 1.0;
  var norm = 0.0;
  for (var i = 0; i < octaves; i++) {
    sum += amp * valueNoise(seed + i * 1013, x * freq, y * freq);
    norm += amp;
    amp *= 0.5;
    freq *= 2;
  }
  return sum / norm;
}
