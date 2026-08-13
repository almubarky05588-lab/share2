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
