import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/cloud_sync.dart';
import 'core/collection.dart';
import 'core/online_config.dart';
import 'core/social.dart';

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

  /// Statistiques calculées par le serveur (runs jouées connecté), null si indisponibles.
  static ProfileStats? stats;

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
        stats = null;
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
      step = 'cartes échangées';
      await _removeTradedAway(col);
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
    final row = await _client.from('profiles').select('friend_code, display_name').eq('id', userId).maybeSingle();
    friendCode = row?['friend_code'] as String?;
    final col = _collection;
    if (col != null && row != null) {
      final (pseudo, push) = reconcilePseudo(local: col.pseudo, remote: row['display_name'] as String?);
      if (pseudo != col.pseudo) await col.setPseudo(pseudo);
      if (push) await _client.from('profiles').update({'display_name': pseudo}).eq('id', userId);
    }
    await _loadStats();
  }

  /// Statistiques du serveur (fonction my_stats). Sans effet si la base n'est pas encore à jour.
  static Future<void> _loadStats() async {
    try {
      stats = ProfileStats.fromRpc(await _client.rpc<dynamic>('my_stats').timeout(_timeout));
    } catch (e) {
      debugPrint('Statistiques en ligne : $e');
    }
  }

  /// Retire de l'appareil les exemplaires donnés lors d'échanges (table traded_away).
  /// Sans effet si la base n'est pas encore à jour.
  static Future<void> _removeTradedAway(Collection col) async {
    try {
      final rows = await _client.from('traded_away').select('card_id, seed').timeout(_timeout);
      final given = givenAwayStillLocal(col.variants, fromRows(rows));
      if (given.isNotEmpty) await col.removeAll(given);
    } on PostgrestException catch (e) {
      debugPrint('Cartes échangées : $e');
    }
  }

  // --- Amis et échanges (supabase/schema.sql) ---
  // Chaque fonction renvoie un message d'erreur en français, ou null si tout s'est bien passé.

  static Future<T> _call<T>(String fn, [Map<String, dynamic>? params]) async =>
      await _client.rpc<dynamic>(fn, params: params).timeout(_timeout) as T;

  static String _socialMessage(Object e) {
    if (e is PostgrestException) return socialErrorMessage('${e.message} ${e.code ?? ''}');
    if (e is TimeoutException) return 'Le serveur ne répond pas.';
    return 'Serveur injoignable.';
  }

  /// Amis et demandes en attente (null + message si impossible).
  static Future<(List<Friend>?, String?)> listFriends() async {
    try {
      return (Friend.fromRows(await _call<List<dynamic>>('list_friends')), null);
    } catch (e) {
      return (null, _socialMessage(e));
    }
  }

  /// Ajoute un ami par son code. Renvoie (vous êtes amis tout de suite ?, erreur).
  static Future<(bool, String?)> addFriend(String code) async {
    try {
      final r = await _call<dynamic>('add_friend', {'p_code': normalizeFriendCode(code)});
      return (r == 'accepted', null);
    } catch (e) {
      return (false, _socialMessage(e));
    }
  }

  static Future<String?> respondFriend(String userId, bool accept) async {
    try {
      await _call<dynamic>('respond_friend', {'p_other': userId, 'p_accept': accept});
      return null;
    } catch (e) {
      return _socialMessage(e);
    }
  }

  static Future<String?> removeFriend(String userId) async {
    try {
      await _call<dynamic>('remove_friend', {'p_other': userId});
      return null;
    } catch (e) {
      return _socialMessage(e);
    }
  }

  /// Exemplaires d'un ami (avec leur identifiant serveur), ou les miens si [userId] est null.
  static Future<(List<ServerCard>?, String?)> cardsOf(String? userId) async {
    try {
      final rows = userId == null
          ? await _call<List<dynamic>>('my_cards')
          : await _call<List<dynamic>>('friend_cards', {'p_friend': userId});
      return (ServerCard.fromRows(rows), null);
    } catch (e) {
      return (null, _socialMessage(e));
    }
  }

  static Future<String?> proposeTrade(String toUser, int offeredRowId, int requestedRowId) async {
    try {
      await _call<dynamic>('propose_trade', {'p_to': toUser, 'p_offered': offeredRowId, 'p_requested': requestedRowId});
      return null;
    } catch (e) {
      return _socialMessage(e);
    }
  }

  /// Accepte un échange reçu, puis met la collection de l'appareil à jour.
  /// Renvoie (accepté ?, erreur) ; accepté = false sans erreur : un exemplaire n'était plus disponible.
  static Future<(bool, String?)> acceptTrade(int tradeId) async {
    try {
      final r = await _call<dynamic>('accept_trade', {'p_trade': tradeId});
      await sync();
      return (r == 'accepted', null);
    } catch (e) {
      return (false, _socialMessage(e));
    }
  }

  /// Refuse (si reçu) ou annule (si envoyé) un échange en attente.
  static Future<String?> closeTrade(int tradeId) async {
    try {
      await _call<dynamic>('close_trade', {'p_trade': tradeId});
      return null;
    } catch (e) {
      return _socialMessage(e);
    }
  }

  static Future<(List<LeaderboardEntry>?, String?)> leaderboard() async {
    try {
      return (LeaderboardEntry.fromRows(await _call<List<dynamic>>('friends_leaderboard')), null);
    } catch (e) {
      return (null, _socialMessage(e));
    }
  }

  static Future<(List<Trade>?, String?)> myTrades() async {
    try {
      return (Trade.fromRows(await _call<List<dynamic>>('my_trades')), null);
    } catch (e) {
      return (null, _socialMessage(e));
    }
  }

  // --- Pseudo ---

  /// Change le pseudo sur l'appareil, et en ligne si on est connecté.
  /// Renvoie un message d'erreur, ou null si c'est bon.
  static Future<String?> setPseudo(String raw) async {
    final pseudo = normalizePseudo(raw);
    final err = pseudoError(pseudo);
    if (err != null) return err;
    final col = _collection;
    final u = user;
    if (u != null) {
      try {
        await _client.from('profiles').update({'display_name': pseudo}).eq('id', u.id).timeout(_timeout);
      } catch (e) {
        debugPrint('Pseudo en ligne : $e');
        return 'Pseudo non enregistré en ligne : ${_syncMessage(e)}';
      }
    }
    await col?.setPseudo(pseudo);
    _bump();
    return null;
  }

  // --- Runs validées par le serveur (supabase/schema.sql : start_run, finish_run) ---

  /// Ouvre une run côté serveur. Renvoie son identifiant, ou null (hors ligne, pas connecté,
  /// base pas à jour, limite du jour atteinte) : la run se joue quand même.
  static Future<String?> startRun() async {
    if (user == null) return null;
    try {
      final id = await _client.rpc<dynamic>('start_run').timeout(_timeout);
      return id is String ? id : null;
    } catch (e) {
      debugPrint('Début de run en ligne : $e');
      return null;
    }
  }

  /// Ferme la run côté serveur, qui ajoute lui-même ses cartes à la collection en ligne.
  /// Si la run n'a pas pu être ouverte ou est refusée, envoi direct comme avant.
  // PROVISOIRE : l'envoi direct (et la synchro de la collection de l'appareil) reste permis
  // tant que Clem n'a pas décidé du sort des cartes gagnées hors ligne (ROADMAP, Questions).
  static Future<void> finishRun(Future<String?> runId,
      {required int kills, required int coins, required List<(int, int)> cards}) async {
    if (user == null) return;
    final id = await runId;
    if (id != null) {
      try {
        final added = await _client.rpc<dynamic>('finish_run', params: {
          'p_run': id,
          'p_kills': kills,
          'p_coins': coins,
          'p_cards': runCardsPayload(cards),
        }).timeout(_timeout);
        if (added is int) onlineCount += added;
        await _loadStats();
        _bump();
        return;
      } catch (e) {
        debugPrint('Fin de run en ligne : $e');
      }
    }
    await pushCards(cards);
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
