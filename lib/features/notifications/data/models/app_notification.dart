class AppNotification {
  final int id;
  final String title;
  final String message;
  final String type; // 'success' or 'info'
  final String createdAt; // ISO 8601
  final String? eventKey; // dedup key

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.eventKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'createdAt': createdAt,
        'eventKey': eventKey,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] ?? 0,
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        type: json['type'] ?? 'info',
        createdAt: json['createdAt'] ?? '',
        eventKey: json['eventKey'],
      );
}
