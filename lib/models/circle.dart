class Circle {
  const Circle({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;

  factory Circle.fromMap(Map<String, dynamic> map) => Circle(
        id: map['id'] as String,
        name: map['name'] as String,
        inviteCode: map['invite_code'] as String,
        ownerId: map['owner_id'] as String,
      );
}
