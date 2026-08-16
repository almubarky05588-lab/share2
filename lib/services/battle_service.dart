import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/battle.dart';
import '../models/jump.dart';
import 'supabase_service.dart';

/// كل ما يخصّ النزال والقفزة والسوق والتحكيم
class BattleService {
  BattleService._();
  static final instance = BattleService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  static const _cols = '''
    *,
    challenger:profiles!battles_challenger_id_fkey(id, handle, name, avatar_url, verified),
    opponent:profiles!battles_opponent_id_fkey(id, handle, name, avatar_url, verified)
  ''';

  // ── النزال ───────────────────────────────────────────────

  /// إنشاء تحدٍّ
  Future<void> challenge({
    required String opponentId,
    required String opponentText,
    required String myText,
    required BattleTopic topic,
    int durationHours = 6,
    String? opponentPostId,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    await _db.from('battles').insert({
      'challenger_id': uid,
      'opponent_id': opponentId,
      'challenger_text': myText,
      'opponent_text': opponentText,
      'opponent_post_id': opponentPostId,
      'topic': topic.key,
      'duration_hours': durationHours,
      'status': 'pending',
    });
  }

  /// قبول التحدي
  Future<void> accept(String battleId) async {
    await _db.rpc('accept_battle', params: {'battle_id': battleId});
  }

  /// رفض التحدي
  Future<void> decline(String battleId) async {
    await _db
        .from('battles')
        .update({'status': 'declined'}).eq('id', battleId);
  }

  /// إنهاء النزالات المنتهية — تُستدعى عند فتح الشاشة
  Future<void> finishDue() async {
    try {
      await _db.rpc('finish_due_battles');
    } catch (_) {}
  }

  Future<Map<String, String>> _myVotes(List<String> battleIds) async {
    final uid = _uid;
    if (uid == null || battleIds.isEmpty) return {};

    final rows = await _db
        .from('battle_votes')
        .select('battle_id, side')
        .eq('user_id', uid)
        .inFilter('battle_id', battleIds);

    return {
      for (final r in rows)
        r['battle_id'].toString(): r['side'] as String,
    };
  }

  Future<List<Battle>> _build(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'].toString()).toList();
    final votes = await _myVotes(ids);

    return rows
        .map((r) => Battle.fromRow(r, myVote: votes[r['id'].toString()]))
        .toList();
  }

  /// النزالات النشطة — الأقرب انتهاءً أولًا
  Future<List<Battle>> fetchActive({BattleTopic? topic}) async {
    await finishDue();

    var q = _db.from('battles').select(_cols).eq('status', 'active');
    if (topic != null) q = q.eq('topic', topic.key);

    final rows = await q.order('ends_at', ascending: true).limit(40);
    return _build(rows.cast<Map<String, dynamic>>());
  }

  /// النزالات المتقاربة — الأكثر إثارة
  Future<List<Battle>> fetchHot() async {
    await finishDue();

    final rows = await _db
        .from('battles')
        .select(_cols)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(60);

    final list = await _build(rows.cast<Map<String, dynamic>>());

    list.sort((a, b) {
      final da = (a.challengerRatio - 0.5).abs();
      final db = (b.challengerRatio - 0.5).abs();
      final c = da.compareTo(db);
      return c != 0 ? c : b.totalVotes.compareTo(a.totalVotes);
    });

    return list.take(30).toList();
  }

  /// نزال واحد للتايم لاين — الأقل أصواتًا أولًا
  Future<Battle?> fetchForTimeline() async {
    await finishDue();

    final uid = _uid;
    if (uid == null) return null;

    final rows = await _db
        .from('battles')
        .select(_cols)
        .eq('status', 'active')
        .limit(30);

    final list = await _build(rows.cast<Map<String, dynamic>>());

    final fresh = list
        .where((b) =>
            !b.voted &&
            b.challenger.userId != uid &&
            b.opponent.userId != uid)
        .toList()
      ..sort((a, b) => a.totalVotes.compareTo(b.totalVotes));

    return fresh.isEmpty ? null : fresh.first;
  }

  /// التحديات الواردة لي
  Future<List<Battle>> fetchPending() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _db
        .from('battles')
        .select(_cols)
        .eq('opponent_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return _build(rows.cast<Map<String, dynamic>>());
  }

  /// نزالات مستخدم
  Future<List<Battle>> fetchUserBattles(String userId) async {
    await finishDue();

    final rows = await _db
        .from('battles')
        .select(_cols)
        .or('challenger_id.eq.$userId,opponent_id.eq.$userId')
        .inFilter('status', ['active', 'finished'])
        .order('created_at', ascending: false)
        .limit(40);

    return _build(rows.cast<Map<String, dynamic>>());
  }

  /// التصويت
  Future<void> vote(String battleId, String side) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    await _db.from('battle_votes').insert({
      'battle_id': battleId,
      'user_id': uid,
      'side': side,
    });
  }

  /// بث حي للأصوات
  RealtimeChannel watchVotes(void Function() onChange) {
    return _db
        .channel('public:battle_votes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'battle_votes',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  Future<void> unwatch(RealtimeChannel c) => _db.removeChannel(c);

  /// كم نزالًا بدأت اليوم
  Future<int> todayBattlesCount() async {
    final uid = _uid;
    if (uid == null) return 0;

    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();

    try {
      return await _db
          .from('battles')
          .count()
          .eq('challenger_id', uid)
          .gt('created_at', since);
    } catch (_) {
      return 0;
    }
  }

  // ── القفزة ───────────────────────────────────────────────

  Future<List<Jump>> fetchMyJumps() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _db
        .from('jumps')
        .select('*')
        .eq('owner_id', uid)
        .order('created_at', ascending: false);

    return rows.map<Jump>((r) => Jump.fromRow(r)).toList();
  }

  /// استخدام القفزة على منشور
  Future<void> useJump(String jumpId, String postId) async {
    await _db.from('jumps').update({
      'post_id': postId,
      'status': 'used',
      'used_at': DateTime.now().toUtc().toIso8601String(),
      'review_status': 'pending',
    }).eq('id', jumpId);
  }

  /// إهداء القفزة
  Future<void> giftJump(String jumpId, String toUserId) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    await _db.from('jump_transfers').insert({
      'jump_id': jumpId,
      'from_id': uid,
      'to_id': toUserId,
      'kind': 'gift',
    });
  }

  // ── السوق ────────────────────────────────────────────────

  Future<void> listJump({
    required String jumpId,
    required String contact,
    String? priceNote,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    await _db.from('jump_listings').insert({
      'jump_id': jumpId,
      'seller_id': uid,
      'contact': contact,
      'price_note': priceNote,
      'note': note,
    });

    await _db.from('jumps').update({'status': 'listed'}).eq('id', jumpId);
  }

  Future<void> cancelListing(String listingId, String jumpId) async {
    await _db
        .from('jump_listings')
        .update({'status': 'cancelled'}).eq('id', listingId);

    await _db.from('jumps').update({'status': 'available'}).eq('id', jumpId);
  }

  Future<List<JumpListing>> fetchMarket() async {
    final rows = await _db
        .from('jump_listings')
        .select('''
          *,
          seller:profiles!jump_listings_seller_id_fkey(id, handle, name, avatar_url, verified),
          jump:jumps(reach_cap, granted_rank)
        ''')
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .limit(50);

    return rows
        .map<JumpListing>((r) => JumpListing.fromRow(
              r,
              formatTime: SupabaseService.formatTimeAgo,
            ))
        .toList();
  }

  /// بدء تحويل بيع
  Future<void> startSaleTransfer({
    required String jumpId,
    required String buyerId,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    await _db.from('jump_transfers').insert({
      'jump_id': jumpId,
      'from_id': uid,
      'to_id': buyerId,
      'kind': 'sale',
    });
  }

  /// التحويلات الواردة لي
  Future<List<Map<String, dynamic>>> fetchIncomingTransfers() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _db
        .from('jump_transfers')
        .select('''
          *,
          from:profiles!jump_transfers_from_id_fkey(id, handle, name, avatar_url, verified),
          jump:jumps(reach_cap, granted_rank)
        ''')
        .eq('to_id', uid)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> confirmTransfer(String transferId) async {
    await _db.rpc('confirm_transfer', params: {'transfer_id': transferId});
  }

  Future<void> rejectTransfer(String transferId) async {
    await _db
        .from('jump_transfers')
        .update({'status': 'rejected'}).eq('id', transferId);
  }

  // ── التحكيم ──────────────────────────────────────────────

  Future<String> openDispute({
    required String transferId,
    required String jumpId,
    required String against,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final row = await _db
        .from('disputes')
        .insert({
          'transfer_id': transferId,
          'jump_id': jumpId,
          'raised_by': uid,
          'against': against,
          'reason': reason,
        })
        .select('id')
        .single();

    return row['id'].toString();
  }

  /// رفع دليل — حاوية خاصة
  Future<void> uploadEvidence({
    required String disputeId,
    required File file,
    String? note,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    final ext = file.path.split('.').last.toLowerCase();
    final path =
        '$uid/$disputeId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('dispute-evidence').upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime),
        );

    await _db.from('dispute_evidence').insert({
      'dispute_id': disputeId,
      'user_id': uid,
      'file_path': path,
      'file_type': mime,
      'note': note,
    });
  }

  Future<List<Map<String, dynamic>>> fetchMyDisputes() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _db
        .from('disputes')
        .select('*')
        .or('raised_by.eq.$uid,against.eq.$uid')
        .order('created_at', ascending: false);

    return rows.cast<Map<String, dynamic>>();
  }
}
