enum AlertType { arrival, departure, sos, battery, speed, info }

class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final String id;
  final String memberId;
  final String memberName;
  final AlertType type;
  final String title;
  final String body;
  final DateTime timestamp;

  factory AlertEvent.fromMap(
    Map<String, dynamic> map, {
    String memberName = 'Member',
  }) =>
      AlertEvent(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: memberName,
        type: AlertType.values.firstWhere(
          (value) => value.name == map['type'],
          orElse: () => AlertType.info,
        ),
        title: map['title'] as String? ?? 'Circle update',
        body: map['body'] as String? ?? '',
        timestamp: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}
