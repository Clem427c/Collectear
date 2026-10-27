import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cloud_sync.dart';
import 'core/collection.dart';
import 'core/online_config.dart';

/// État de la synchronisation de la collection, affiché dans le Profil.
enum SyncState { idle, syncing, done, error }

/// Connexion au serveur en ligne (Supabase). Tout est facultatif : sans configuration,
/// ou si le serveur ne répond pas, le jeu fonctionne hors ligne avec la collection locale.
class Online {
  Online._();

  static const OnlineConfig config = OnlineConfig.fromEnvironment;
  static bool _initialized = false;
  static Collection? _collection;
  static StreamSubscription<AuthState>? _authSub;

  /// Incrémenté à chaque changement visible (connexion, synchro) : les écrans s'y abonnent.
  static final ValueNotifier<int> revision = ValueNotifier(0);
  static SyncState syncState = SyncState.idle;
  static String? lastError;
  static int onlineCount = 0;
  static String? friendCode;

  /// Vrai si le client Supabase est prêt (secrets présents et valides au build).
  static bool get ready => _initialized;

  static SupabaseClient get _client => Supabase.instance.client;

  static User? get user => _initialized ? _client.auth.currentUser : null;

  static Future<void> init() async {
    if (!config.isUsable || _initialized) return;
    try {
      await Supabase.initialize(url: config.cleanUrl, anonKey: config.cleanKey);
      _initialized = true;
    } catch (e) {
      debugPrint('Supabase indisponible : $e');
    }
  }

  /// Branche la collection locale : synchro au démarrage si déjà connecté, et à chaque connexion
  /// (y compris via le lien magique ouvert dans le navigateur).
  static void attach(Collection collection) {
    _collection = collection;
    if (!_initialized) return;
    _authSub ??= _client.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.initialSession) {
        if (s.session != null) Future<void>.delayed(const Duration(milliseconds: 300), sync);
      } else if (s.event == AuthChangeEvent.signedOut) {
        friendCode = null;
        onlineCount = 0;
        syncState = SyncState.idle;
        _bump();
      }
    });
  }

  static void _bump() => revision.value++;

  /// Vérifie que le serveur répond et accepte la clé publique (service d'authentification).
  static Future<bool> ping() async {
    if (!config.isUsable) return false;
    try {
      final res = await http
          .get(Uri.parse('${config.cleanUrl}/auth/v1/health'), headers: {'apikey': config.cleanKey})
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- Connexion par e-mail (code à 6 chiffres ou lien magique) ---

  /// Lien de retour de l'APK : ouvre l'appli (intent-filter ajouté au manifeste par la CI).
  /// À déclarer dans Supabase → Authentication → URL Configuration → Redirect URLs.
  static const appRedirect = 'com.clem427c.collectear://login-callback';

  /// Envoie l'e-mail de connexion. Le lien ramène sur la page du jeu (web) ou ouvre l'appli (APK) ;
  /// supabase_flutter récupère alors la session tout seul.
  static Future<String?> sendCode(String email) async {
    try {
      final redirect = kIsWeb ? '${Uri.base.origin}${Uri.base.path}' : appRedirect;
      await _client.auth.signInWithOtp(email: email.trim(), emailRedirectTo: redirect);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return 'Serveur injoignable ($e)';
    }
  }

  /// Valide le code reçu par e-mail. Renvoie un message d'erreur, ou null si c'est bon.
  static Future<String?> verifyCode(String email, String code) async {
    try {
      await _client.auth.verifyOTP(email: email.trim(), token: code.replaceAll(' ', ''), type: OtpType.email);
      return null;
    } on AuthException catch (e) {
      return _authMessage(e);
    } catch (e) {
      return 'Serveur injoignable ($e)';
    }
  }

  static Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Déconnexion : $e');
    }
    _bump();
  }

  static String _authMessage(AuthException e) => authErrorMessage(e.message, code: e.code);

  // --- Synchronisation de la collection ---

  static const _table = 'owned_cards';
  static const _pageSize = 1000; // limite par défaut de l'API Supabase
  static const _batchSize = 500;

  /// Union de la collection locale et de la collection en ligne (rien n'est supprimé).
  // PROVISOIRE : la collection locale est celle de l'appareil ; si un autre compte se connecte
  // sur le même appareil, les cartes locales sont aussi envoyées sur ce compte.
  static Future<void> sync() async {
    final u = user;
    final col = _collection;
    if (u == null || col == null || syncState == SyncState.syncing) return;
    syncState = SyncState.syncing;
    lastError = null;
    var step = 'profil';
    try {
      _bump();
      // Chaque appel au serveur a un délai maximal : la synchro ne peut plus rester bloquée.
      await _loadProfile(u.id).timeout(_timeout);
      step = 'lecture de la collection';
      final remote = <(int, int)>[];
      for (var from = 0;; from += _pageSize) {
        final rows = await _client
            .from(_table)
            .select('card_id, seed')
            .order('id')
            .range(from, from + _pageSize - 1)
            .timeout(_timeout);
        remote.addAll(fromRows(rows));
        if (rows.length < _pageSize) break;
      }
      step = 'envoi des cartes';
      final plan = planSync(col.variants, remote);
      for (final batch in chunked(plan.toUpload, _batchSize)) {
        await _client
            .from(_table)
            .upsert(toRows(u.id, batch), onConflict: 'user_id,card_id,seed', ignoreDuplicates: true)
            .timeout(_timeout);
      }
      step = 'ajout local';
      if (plan.toAddLocally.isNotEmpty) await col.addAll(plan.toAddLocally);
      onlineCount = remote.toSet().length + plan.toUpload.length;
      syncState = SyncState.done;
    } catch (e) {
      lastError = '${_syncMessage(e)} (étape : $step)';
      syncState = SyncState.error;
      debugPrint('Synchro ($step) : $e');
    } finally {
      if (syncState == SyncState.syncing) syncState = SyncState.error;
      _bump();
    }
  }

  static const _timeout = Duration(seconds: 15);

  /// Envoie les cartes d'une run qui vient de finir (en cas d'échec, la prochaine synchro rattrape).
  static Future<void> pushCards(Iterable<(int, int)> items) async {
    final u = user;
    final list = items.toList();
    if (u == null || list.isEmpty) return;
    try {
      await _client.from(_table).upsert(toRows(u.id, list), onConflict: 'user_id,card_id,seed', ignoreDuplicates: true);
      onlineCount += list.length;
      _bump();
    } catch (e) {
      debugPrint('Envoi des cartes : $e');
    }
  }

  static Future<void> _loadProfile(String userId) async {
    final row = await _client.from('profiles').select('friend_code').eq('id', userId).maybeSingle();
    friendCode = row?['friend_code'] as String?;
  }

  static String _syncMessage(Object e) {
    if (e is PostgrestException && (e.code == '42P01' || e.code == 'PGRST205' || e.message.contains('does not exist'))) {
      return 'Base pas encore créée : colle supabase/schema.sql dans l\'éditeur SQL de Supabase.';
    }
    if (e is PostgrestException) return '${e.message} [${e.code}]';
    if (e is TimeoutException) return 'Le serveur ne répond pas';
    return 'Erreur : $e';
  }
}
