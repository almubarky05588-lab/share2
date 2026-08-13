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
part of 'supabase_service.dart';

/// الملف الشخصي · المتابعة · الحظر · الإشعارات · الرسائل
extension SupabaseProfileApi on SupabaseService {
  // ── الحظر ────────────────────────────────────────────────

  Future<void> setBlock(String userId, bool on) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (on) {
      await _db
          .from('blocks')
          .upsert({'blocker_id': uid, 'blocked_id': userId});
    } else {
      await _db
          .from('blocks')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', userId);
    }
  }

  Future<bool> isBlocked(String userId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final row = await _db
        .from('blocks')
        .select('blocked_id')
        .eq('blocker_id', uid)
        .eq('blocked_id', userId)
        .maybeSingle();

    return row != null;
  }

  Future<bool> blockedMe(String userId) async {
    final uid = currentUserId;
    if (uid == null) return false;

    final row = await _db
        .from('blocks')
        .select('blocker_id')
        .eq('blocker_id', userId)
        .eq('blocked_id', uid)
        .maybeSingle();

    return row != null;
  }

  Future<List<UserProfile>> fetchBlockedUsers() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final rows = await _db
        .from('blocks')
        .select(
          'blocked:profiles!blocks_blocked_id_fkey(id, handle, name, avatar_url, verified)',
        )
        .eq('blocker_id', uid);

    return rows
        .map((r) => r['blocked'])
        .whereType<Map<String, dynamic>>()
        .map<UserProfile>(_light)
        .toList();
  }

  UserProfile _light(Map<String, dynamic> r) => UserProfile(
        id: r['id'].toString(),
        name: r['name'] as String? ?? '',
        handle: r['handle'] as String? ?? '',
        bio: r['bio'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String?,
        verified: r['verified'] as bool? ?? false,
        followers: 0,
        following: 0,
        posts: 0,
      );

  // ── قوائم المتابعة ───────────────────────────────────────

  Future<List<UserProfile>> fetchFollowers(String userId) async {
    final rows = await _db
        .from('follows')
        .select(
          'follower:profiles!follows_follower_id_fkey(id, handle, name, bio, avatar_url, verified)',
        )
        .eq('following_id', userId)
        .limit(100);

    return rows
        .map((r) => r['follower'])
        .whereType<Map<String, dynamic>>()
        .map<UserProfile>(_light)
        .toList();
  }

  Future<List<UserProfile>> fetchFollowing(String userId) async {
    final rows = await _db
        .from('follows')
        .select(
          'following:profiles!follows_following_id_fkey(id, handle, name, bio, avatar_url, verified)',
        )
        .eq('follower_id', userId)
        .limit(100);

    return rows
        .map((r) => r['following'])
        .whereType<Map<String, dynamic>>()
        .map<UserProfile>(_light)
        .toList();
  }

  // ── الإشعارات ────────────────────────────────────────────

  Future<DateTime?> _seenAt() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final row = await _db
        .from('profiles')
        .select('notifications_seen_at')
        .eq('id', uid)
        .maybeSingle();

    final v = row?['notifications_seen_at'] as String?;
    return v == null ? null : DateTime.tryParse(v);
  }

  Future<List<NotificationItem>> fetchNotifications() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final seen = await _seenAt();

    final rows = await _db
        .from('notifications_feed')
        .select('*')
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(60);

    return rows.map<NotificationItem>((r) {
      final created = DateTime.tryParse(r['created_at'] as String? ?? '');
      final unread =
          seen == null || (created != null && created.isAfter(seen));

      return NotificationItem.fromRow(
        r,
        formatTime: SupabaseService.formatTimeAgo,
        unread: unread,
      );
    }).toList();
  }

  Future<int> unreadNotificationsCount() async {
    final uid = currentUserId;
    if (uid == null) return 0;

    final seen = await _seenAt();
    if (seen == null) return 0;

    try {
      return await _db
          .from('notifications_feed')
          .count()
          .eq('recipient_id', uid)
          .gt('created_at', seen.toIso8601String());
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationsSeen() async {
    final uid = currentUserId;
    if (uid == null) return;

    await _db.from('profiles').update({
      'notifications_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', uid);
  }

  // ── الرسائل ──────────────────────────────────────────────

  /// يفتح محادثة مع مستخدم — ينشئها إن لم تكن موجودة
  Future<String> openConversationWith(String otherUserId) async {
    final id = await _db.rpc(
      'get_or_create_conversation',
      params: {'other_id': otherUserId},
    );
    return id.toString();
  }

  Future<List<Conversation>> fetchConversations() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final rows = await _db
        .from('conversation_members')
        .select(
          'conversation:conversations(id, last_message_at, '
          'members:conversation_members(user:profiles(id, handle, name, avatar_url, verified)), '
          'messages(body, sender_id, created_at))',
        )
        .eq('user_id', uid)
        .limit(50);

    final result = <Conversation>[];

    for (final r in rows) {
      final c = r['conversation'] as Map<String, dynamic>?;
      if (c == null) continue;

      final members = (c['members'] as List? ?? const [])
          .map((m) => (m as Map<String, dynamic>)['user'])
          .whereType<Map<String, dynamic>>()
          .where((u) => u['id'] != uid)
          .toList();
      if (members.isEmpty) continue;
      final other = members.first;

      final msgs = (c['messages'] as List? ?? const [])
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
      final last = msgs.isEmpty ? null : msgs.first;

      result.add(Conversation(
        id: c['id'].toString(),
        otherUserId: other['id']?.toString() ?? '',
        name: other['name'] as String? ?? '',
        handle: other['handle'] as String? ?? '',
        avatarUrl: other['avatar_url'] as String?,
        verified: other['verified'] as bool? ?? false,
        lastMessage: last?['body'] as String? ?? '',
        sentByMe: last != null && last['sender_id'] == uid,
        time: SupabaseService.formatTimeAgo(
            c['last_message_at'] as String?),
      ));
    }

    return result;
  }

  Future<List<Message>> fetchMessages(String conversationId) async {
    final uid = currentUserId;
    final rows = await _db
        .from('messages')
        .select('id, body, sender_id, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');

    return rows
        .map<Message>((r) => Message(
              id: r['id'].toString(),
              body: r['body'] as String? ?? '',
              time: SupabaseService.formatClock(r['created_at'] as String?),
              fromMe: r['sender_id'] == uid,
            ))
        .toList();
  }

  Future<void> sendMessage(String conversationId, String body) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');
    await _db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'body': body,
    });
  }

  Stream<List<Message>> messageStream(String conversationId) {
    final uid = currentUserId;
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .map((rows) => rows
            .map((r) => Message(
                  id: r['id'].toString(),
                  body: r['body'] as String? ?? '',
                  time: SupabaseService.formatClock(
                      r['created_at'] as String?),
                  fromMe: r['sender_id'] == uid,
                ))
            .toList());
  }

  // ── الملف الشخصي ─────────────────────────────────────────

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _db
        .from('profiles')
        .select(
          'id, handle, name, bio, location, website, avatar_url, cover_url, verified, created_at',
        )
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    final followers =
        await _db.from('follows').count().eq('following_id', userId);
    final following =
        await _db.from('follows').count().eq('follower_id', userId);

    final posts = await _db
        .from('posts')
        .count()
        .eq('author_id', userId)
        .isFilter('reshare_of', null)
        .isFilter('reply_to', null);

    final me = currentUserId;
    var isFollowing = false;
    var followsYou = false;
    var blocked = false;
    var hasBlockedMe = false;

    if (me != null && me != userId) {
      final a = await _db
          .from('follows')
          .select('follower_id')
          .eq('follower_id', me)
          .eq('following_id', userId)
          .maybeSingle();
      isFollowing = a != null;

      final b = await _db
          .from('follows')
          .select('follower_id')
          .eq('follower_id', userId)
          .eq('following_id', me)
          .maybeSingle();
      followsYou = b != null;

      blocked = await isBlocked(userId);
      hasBlockedMe = await blockedMe(userId);
    }

    return UserProfile(
      id: row['id'].toString(),
      name: row['name'] as String? ?? '',
      handle: row['handle'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      location: row['location'] as String?,
      website: row['website'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      coverUrl: row['cover_url'] as String?,
      verified: row['verified'] as bool? ?? false,
      joined: SupabaseService.formatJoined(row['created_at'] as String?),
      followers: followers,
      following: following,
      posts: posts,
      isFollowing: isFollowing,
      followsYou: followsYou,
      isBlocked: blocked,
      blockedMe: hasBlockedMe,
    );
  }

  Future<UserProfile?> fetchMyProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return fetchProfile(uid);
  }

  Future<bool> isHandleAvailable(String handle) async {
    final uid = currentUserId;
    final row = await _db
        .from('profiles')
        .select('id')
        .eq('handle', handle.toLowerCase())
        .maybeSingle();

    return row == null || row['id'] == uid;
  }

  Future<void> updateProfile({
    String? name,
    String? handle,
    String? bio,
    String? location,
    String? website,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (handle != null) data['handle'] = handle.toLowerCase();
    if (bio != null) data['bio'] = bio;
    if (location != null) data['location'] = location;
    if (website != null) data['website'] = website;
    if (data.isEmpty) return;

    await _db.from('profiles').update(data).eq('id', uid);
  }

  Future<void> setFollow(String userId, bool follow) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (follow) {
      await _db
          .from('follows')
          .upsert({'follower_id': uid, 'following_id': userId});
    } else {
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', userId);
    }
  }

  Future<List<UserProfile>> searchUsers(String query) async {
    final q = query.replaceAll('@', '').trim();

    var builder = _db
        .from('profiles')
        .select('id, handle, name, bio, avatar_url, verified');

    if (q.isNotEmpty) {
      builder = builder.or('handle.ilike.%$q%,name.ilike.%$q%');
    }

    final rows = await builder.limit(20);
    return rows.map<UserProfile>(_light).toList();
  }
}
