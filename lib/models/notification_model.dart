class NotificationItemModel {
  final String id;
  final String title;
  final String description;
  final String time;
  final bool isRead;
  final String type;

  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    this.isRead = false,
    this.type = 'system',
  });

  NotificationItemModel copyWith({
    String? id,
    String? title,
    String? description,
    String? time,
    bool? isRead,
    String? type,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      time: time ?? this.time,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
    );
  }
}
