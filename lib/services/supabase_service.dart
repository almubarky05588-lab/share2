import 'dart:io';

import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/notification_item.dart';
import '../models/post.dart';
import '../models/user_profile.dart';

part 'supabase_service_profile.dart';

/// كل استعلامات Supabase في مكان واحد
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  String? get currentUserId => _db.auth.currentUser?.id;
  String? get currentEmail => _db.auth.currentUser?.email;
  bool get isSignedIn => currentUserId != null;

  static const _feedColumns = '*';

  // ── المصادقة ─────────────────────────────────────────────

  Future<void> signUp({
    required String email,
    required String password,
    required String handle,
    required String name,
  }) async {
    await _db.auth.signUp(
      email: email,
      password: password,
      data: {'handle': handle, 'name': name},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _db.auth.signOut();

  Future<void> changeEmail(String newEmail) async {
    await _db.auth.updateUser(UserAttributes(email: newEmail));
  }

  // ── قراءة المنشورات ──────────────────────────────────────

  Post _post(Map<String, dynamic> row) =>
      Post.fromFeedRow(row, formatTime: formatTimeAgo);

  Future<List<Post>> fetchTimeline({bool followingOnly = false}) async {
    final uid = currentUserId;

    var query =
        _db.from('posts_feed').select(_feedColumns).isFilter('reply_to', null);

    if (followingOnly && uid != null) {
      final follows = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);

      final ids = follows.map((e) => e['following_id'] as String).toList()
        ..add(uid);
      query = query.inFilter('author_id', ids);
    }

    final rows = await query.order('created_at', ascending: false).limit(50);
    return rows.map<Post>(_post).toList();
  }

  /// بث حي لأي منشور جديد
  RealtimeChannel watchNewPosts(void Function() onInsert) {
    return _db
        .channel('public:posts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (_) => onInsert(),
        )
        .subscribe();
  }

  Future<void> unwatch(RealtimeChannel channel) async {
    await _db.removeChannel(channel);
  }

  Future<int> countPostsSince(DateTime since,
      {bool followingOnly = false}) async {
    final uid = currentUserId;
    if (uid == null) return 0;

    try {
      return await _db
          .from('posts_feed')
          .count()
          .isFilter('reply_to', null)
          .neq('author_id', uid)
          .gt('created_at', since.toUtc().toIso8601String());
    } catch (_) {
      return 0;
    }
  }

  Future<List<Post>> fetchUserPosts(String userId) async {
    final rows = await _db
        .from('posts_feed')
        .select(_feedColumns)
        .eq('author_id', userId)
        .isFilter('reply_to', null)
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map<Post>(_post).toList();
  }

  Future<Post?> fetchPost(String postId) async {
    final row = await _db
        .from('posts_feed')
        .select(_feedColumns)
        .eq('id', postId)
        .maybeSingle();

    return row == null ? null : _post(row);
  }

  Future<List<Post>> fetchReplies(String postId) async {
    final rows = await _db
        .from('posts_feed')
        .select(_feedColumns)
        .eq('reply_to', postId)
        .order('created_at');

    return rows.map<Post>(_post).toList();
  }

  Future<List<Post>> fetchByHashtag(String tag) async {
    final clean = tag.replaceAll('#', '').toLowerCase();

    final rows = await _db
        .from('post_hashtags')
        .select('post_id, hashtags!inner(tag)')
        .eq('hashtags.tag', clean)
        .limit(50);

    final ids = rows.map((e) => e['post_id'] as String).toList();
    if (ids.isEmpty) return [];

    final posts = await _db
        .from('posts_feed')
        .select(_feedColumns)
        .inFilter('id', ids)
        .order('created_at', ascending: false);

    return posts.map<Post>(_post).toList();
  }

  Future<List<({String tag, int count})>> fetchTrendingHashtags() async {
    final rows =
        await _db.from('post_hashtags').select('hashtags(tag)').limit(300);

    final counts = <String, int>{};
    for (final r in rows) {
      final h = r['hashtags'] as Map<String, dynamic>?;
      final tag = h?['tag'] as String?;
      if (tag == null) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }

    final list =
        counts.entries.map((e) => (tag: e.key, count: e.value)).toList()
          ..sort((a, b) => b.count.compareTo(a.count));

    return list.take(20).toList();
  }

  Future<List<Post>> fetchLikedPosts(String userId) async {
    final rows = await _db
        .from('likes')
        .select('post_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    final ids = rows.map((e) => e['post_id'] as String).toList();
    if (ids.isEmpty) return [];

    final posts = await _db
        .from('posts_feed')
        .select(_feedColumns)
        .inFilter('id', ids)
        .order('created_at', ascending: false);

    return posts.map<Post>(_post).toList();
  }

  Future<void> recordView(String postId) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await _db
          .from('post_views')
          .upsert({'post_id': postId, 'user_id': uid});
    } catch (_) {}
  }

  // ── النشر والتفاعل ───────────────────────────────────────

  Future<void> createPost(
    String body, {
    String? replyTo,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final inserted = await _db
        .from('posts')
        .insert({
          'author_id': uid,
          'body': body,
          'reply_to': replyTo,
          'media_url': mediaUrl,
          'media_type': mediaType,
        })
        .select('id')
        .single();

    await _linkMentions(inserted['id'] as String, body);
  }

  Future<void> _linkMentions(String postId, String body) async {
    final handles = extractHandles(body);
    if (handles.isEmpty) return;

    final users =
        await _db.from('profiles').select('id').inFilter('handle', handles);
    if (users.isEmpty) return;

    for (final u in users) {
      try {
        await _db
            .from('mentions')
            .insert({'post_id': postId, 'user_id': u['id']});
      } catch (_) {}
    }
  }

  Future<void> toggleReshare(String postId, bool on) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (on) {
      try {
        await _db.from('posts').insert({
          'author_id': uid,
          'reshare_of': postId,
        });
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
      }
    } else {
      await _db
          .from('posts')
          .delete()
          .eq('author_id', uid)
          .eq('reshare_of', postId);
    }
  }

  Future<void> setLike(String postId, bool liked) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (liked) {
      await _db.from('likes').upsert({'post_id': postId, 'user_id': uid});
    } else {
      await _db
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  Future<void> deletePost(String postId) async {
    await _db.from('posts').delete().eq('id', postId);
  }

  String postLink(String postId) => 'https://share.sa/p/$postId';

  static List<String> extractHandles(String body) {
    final re = RegExp(r'@([a-zA-Z0-9._]{3,20})');
    return re.allMatches(body).map((m) => m.group(1)!).toSet().toList();
  }

  Future<String?> userIdByHandle(String handle) async {
    final row = await _db
        .from('profiles')
        .select('id')
        .eq('handle', handle.replaceAll('@', '').toLowerCase())
        .maybeSingle();

    return row?['id'] as String?;
  }

  // ── رفع الوسائط ──────────────────────────────────────────

  Future<({String url, String type})> uploadMedia(File file) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final mime = lookupMimeType(file.path) ?? 'application/octet-stream';
    final isVideo = mime.startsWith('video/');
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('post-media').upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );

    final url = _db.storage.from('post-media').getPublicUrl(path);
    return (url: url, type: isVideo ? 'video' : 'image');
  }

  Future<String> uploadAvatar(File file) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('avatars').upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );

    final url = _db.storage.from('avatars').getPublicUrl(path);
    await _db.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }

  /// رفع صورة الغلاف
  Future<String> uploadCover(File file) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final mime = lookupMimeType(file.path) ?? 'image/jpeg';
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$uid/cover_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('avatars').upload(
          path,
          file,
          fileOptions: FileOptions(contentType: mime, upsert: true),
        );

    final url = _db.storage.from('avatars').getPublicUrl(path);
    await _db.from('profiles').update({'cover_url': url}).eq('id', uid);
    return url;
  }

  // ── تنسيق ────────────────────────────────────────────────

  static String formatTimeAgo(String? iso) {
    if (iso == null) return '';
    final then = DateTime.tryParse(iso)?.toLocal();
    if (then == null) return '';

    final diff = DateTime.now().difference(then);
    if (diff.inSeconds < 60) return 'الآن';
    if (diff.inMinutes < 60) return '${diff.inMinutes}د';
    if (diff.inHours < 24) return '${diff.inHours}س';
    if (diff.inDays == 1) return 'أمس';
    if (diff.inDays < 7) return '${diff.inDays} أيام';
    return '${then.day}/${then.month}';
  }

  static String formatClock(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  static String formatJoined(String? iso) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return 'انضمّ في ${months[d.month - 1]} ${d.year}';
  }
}
