import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/conversation.dart';
import '../models/message.dart';
import '../models/notification_item.dart';
import '../models/post.dart';
import '../models/user_profile.dart';

/// كل استعلامات Supabase في مكان واحد
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  String? get currentUserId => _db.auth.currentUser?.id;
  bool get isSignedIn => currentUserId != null;

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

  // ── التايم لاين ──────────────────────────────────────────

  /// الفيد العام أو منشورات من أتابعهم
  Future<List<Post>> fetchTimeline({bool followingOnly = false}) async {
    final uid = currentUserId;

    var query = _db.from('posts').select(
          'id, body, media_url, created_at, reshare_of, '
          'author:profiles!posts_author_id_fkey(id, handle, name, verified), '
          'likes(count), reshares:posts!posts_reshare_of_fkey(count), '
          'replies:posts!posts_reply_to_fkey(count)',
        );

    if (followingOnly && uid != null) {
      final follows = await _db
          .from('follows')
          .select('following_id')
          .eq('follower_id', uid);
      final ids = follows.map((e) => e['following_id'] as String).toList();
      if (ids.isEmpty) return [];
      query = query.inFilter('author_id', ids);
    }

    final rows = await query.order('created_at', ascending: false).limit(50);
    return rows.map<Post>(_postFromRow).toList();
  }

  Future<List<Post>> fetchUserPosts(String userId) async {
    final rows = await _db
        .from('posts')
        .select(
          'id, body, media_url, created_at, reshare_of, '
          'author:profiles!posts_author_id_fkey(id, handle, name, verified), '
          'likes(count), reshares:posts!posts_reshare_of_fkey(count), '
          'replies:posts!posts_reply_to_fkey(count)',
        )
        .eq('author_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return rows.map<Post>(_postFromRow).toList();
  }

  Post _postFromRow(Map<String, dynamic> row) {
    final author = row['author'] as Map<String, dynamic>? ?? const {};

    int countOf(String key) {
      final v = row[key];
      if (v is List && v.isNotEmpty) {
        return (v.first as Map<String, dynamic>)['count'] as int? ?? 0;
      }
      return 0;
    }

    return Post(
      id: row['id'].toString(),
      authorName: author['name'] as String? ?? '',
      handle: author['handle'] as String? ?? '',
      verified: author['verified'] as bool? ?? false,
      body: row['body'] as String? ?? '',
      timeAgo: formatTimeAgo(row['created_at'] as String?),
      hasMedia: row['media_url'] != null,
      likes: countOf('likes'),
      reshares: countOf('reshares'),
      comments: countOf('replies'),
    );
  }

  // ── النشر والتفاعل ───────────────────────────────────────

  Future<void> createPost(String body, {String? replyTo}) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    final inserted = await _db
        .from('posts')
        .insert({'author_id': uid, 'body': body, 'reply_to': replyTo})
        .select('id')
        .single();

    final handles = _extractHandles(body);
    if (handles.isEmpty) return;

    final users = await _db
        .from('profiles')
        .select('id')
        .inFilter('handle', handles);

    if (users.isEmpty) return;

    await _db.from('mentions').insert([
      for (final u in users)
        {'post_id': inserted['id'], 'user_id': u['id']},
    ]);
  }

  Future<void> reshare(String postId) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');
    await _db.from('posts').insert({
      'author_id': uid,
      'reshare_of': postId,
    });
  }

  Future<void> setLike(String postId, bool liked) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (liked) {
      await _db.from('likes').insert({'post_id': postId, 'user_id': uid});
    } else {
      await _db
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  static List<String> _extractHandles(String body) {
    final re = RegExp(r'@([a-zA-Z0-9._]{3,20})');
    return re.allMatches(body).map((m) => m.group(1)!).toSet().toList();
  }

  // ── المنشن والإشعارات ────────────────────────────────────

  Future<List<NotificationItem>> fetchNotifications() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final items = <NotificationItem>[];

    // منشن
    final mentions = await _db
        .from('mentions')
        .select(
          'post:posts(id, body, created_at, reply_to, '
          'author:profiles!posts_author_id_fkey(handle, name, verified))',
        )
        .eq('user_id', uid)
        .limit(30);

    for (final m in mentions) {
      final p = m['post'] as Map<String, dynamic>?;
      if (p == null) continue;
      final a = p['author'] as Map<String, dynamic>? ?? const {};
      items.add(NotificationItem(
        id: 'm_${p['id']}',
        type: p['reply_to'] != null
            ? NotificationType.commentMention
            : NotificationType.mention,
        actorName: a['name'] as String? ?? '',
        handle: a['handle'] as String? ?? '',
        verified: a['verified'] as bool? ?? false,
        timeAgo: formatTimeAgo(p['created_at'] as String?),
        preview: p['body'] as String?,
      ));
    }

    // متابعون جدد
    final follows = await _db
        .from('follows')
        .select(
          'created_at, '
          'follower:profiles!follows_follower_id_fkey(handle, name, verified)',
        )
        .eq('following_id', uid)
        .order('created_at', ascending: false)
        .limit(20);

    for (final f in follows) {
      final a = f['follower'] as Map<String, dynamic>? ?? const {};
      items.add(NotificationItem(
        id: 'f_${a['handle']}',
        type: NotificationType.follow,
        actorName: a['name'] as String? ?? '',
        handle: a['handle'] as String? ?? '',
        verified: a['verified'] as bool? ?? false,
        timeAgo: formatTimeAgo(f['created_at'] as String?),
      ));
    }

    return items;
  }

  // ── الرسائل ──────────────────────────────────────────────

  Future<List<Conversation>> fetchConversations() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final rows = await _db
        .from('conversation_members')
        .select(
          'conversation:conversations(id, last_message_at, '
          'members:conversation_members(user:profiles(id, handle, name, verified)), '
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
        ..sort((a, b) => (b['created_at'] as String)
            .compareTo(a['created_at'] as String));
      final last = msgs.isEmpty ? null : msgs.first;

      result.add(Conversation(
        id: c['id'].toString(),
        name: other['name'] as String? ?? '',
        handle: other['handle'] as String? ?? '',
        verified: other['verified'] as bool? ?? false,
        lastMessage: last?['body'] as String? ?? '',
        sentByMe: last != null && last['sender_id'] == uid,
        time: formatTimeAgo(c['last_message_at'] as String?),
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
              time: formatClock(r['created_at'] as String?),
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

  /// بث مباشر لرسائل محادثة
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
                  time: formatClock(r['created_at'] as String?),
                  fromMe: r['sender_id'] == uid,
                ))
            .toList());
  }

  // ── الملف الشخصي ─────────────────────────────────────────

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _db
        .from('profiles')
        .select('id, handle, name, bio, location, verified, created_at')
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    final followers = await _db
        .from('follows')
        .count()
        .eq('following_id', userId);
    final following = await _db
        .from('follows')
        .count()
        .eq('follower_id', userId);
    final posts = await _db.from('posts').count().eq('author_id', userId);

    final me = currentUserId;
    var isFollowing = false;
    var followsYou = false;

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
    }

    return UserProfile(
      name: row['name'] as String? ?? '',
      handle: row['handle'] as String? ?? '',
      bio: row['bio'] as String? ?? '',
      location: row['location'] as String?,
      verified: row['verified'] as bool? ?? false,
      joined: formatJoined(row['created_at'] as String?),
      followers: followers,
      following: following,
      posts: posts,
      isFollowing: isFollowing,
      followsYou: followsYou,
    );
  }

  Future<void> setFollow(String userId, bool follow) async {
    final uid = currentUserId;
    if (uid == null) throw StateError('غير مسجّل الدخول');

    if (follow) {
      await _db
          .from('follows')
          .insert({'follower_id': uid, 'following_id': userId});
    } else {
      await _db
          .from('follows')
          .delete()
          .eq('follower_id', uid)
          .eq('following_id', userId);
    }
  }

  // ── تنسيق الوقت ──────────────────────────────────────────

  static String formatTimeAgo(String? iso) {
    if (iso == null) return '';
    final then = DateTime.tryParse(iso)?.toLocal();
    if (then == null) return '';

    final diff = DateTime.now().difference(then);
    if (diff.inMinutes < 1) return 'الآن';
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
