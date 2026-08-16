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
        battlePoints: (r['battle_points'] as num?)?.toInt() ?? 0,
      );

  // ── قوائم المتابعة ───────────────────────────────────────

  Future<List<UserProfile>> fetchFollowers(String userId) async {
    final rows = await _db
        .from('follows')
        .select(
          'follower:profiles!follows_follower_id_fkey(id, handle, name, bio, avatar_url, verified, battle_points)',
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
          'following:profiles!follows_following_id_fkey(id, handle, name, bio, avatar_url, verified, battle_points)',
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
        .order('created_at', ascending: true);

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

  /// بث حي للرسائل — مرتّبة من الأقدم للأحدث
  Stream<List<Message>> messageStream(String conversationId) {
    final uid = currentUserId;
    return _db
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .map((rows) {
          final list = rows.toList()
            ..sort((a, b) => (a['created_at'] as String)
                .compareTo(b['created_at'] as String));

          return list
              .map((r) => Message(
                    id: r['id'].toString(),
                    body: r['body'] as String? ?? '',
                    time: SupabaseService.formatClock(
                        r['created_at'] as String?),
                    fromMe: r['sender_id'] == uid,
                  ))
              .toList();
        });
  }

  // ── الملف الشخصي ─────────────────────────────────────────

  Future<UserProfile?> fetchProfile(String userId) async {
    final row = await _db
        .from('profiles')
        .select(
          'id, handle, name, bio, location, website, avatar_url, cover_url, '
          'verified, created_at, battle_points, battles_count, battles_won',
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
      battlePoints: (row['battle_points'] as num?)?.toInt() ?? 0,
      battlesCount: (row['battles_count'] as num?)?.toInt() ?? 0,
      battlesWon: (row['battles_won'] as num?)?.toInt() ?? 0,
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
        .select(
            'id, handle, name, bio, avatar_url, verified, battle_points');

    if (q.isNotEmpty) {
      builder = builder.or('handle.ilike.%$q%,name.ilike.%$q%');
    }

    final rows = await builder.limit(20);
    return rows.map<UserProfile>(_light).toList();
  }
}
