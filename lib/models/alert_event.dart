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
}
