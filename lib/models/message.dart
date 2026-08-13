/// رسالة واحدة داخل المحادثة — الشاشة ٤ من التصميم
class Message {
  const Message({
    required this.id,
    required this.body,
    required this.time,
    required this.fromMe,
  });

  final String id;
  final String body;
  final String time; // 11:02

  /// true = فقاعتي (يمين) · false = فقاعة الطرف الآخر (يسار)
  final bool fromMe;

  /// للربط مع Supabase لاحقًا
  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'].toString(),
        body: map['body'] as String? ?? '',
        time: map['time'] as String? ?? '',
        fromMe: map['from_me'] as bool? ?? false,
      );
}
