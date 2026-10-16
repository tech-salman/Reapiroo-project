class RequestModel {
  final String id;
  final String customerName;
  final String customerAvatar;
  final String serviceType;
  final String date;
  final String time;
  final String address;
  final double price;
  final String status;
  final bool isUrgent;

  const RequestModel({
    required this.id,
    required this.customerName,
    required this.customerAvatar,
    required this.serviceType,
    required this.date,
    required this.time,
    required this.address,
    required this.price,
    this.status = 'New',
    this.isUrgent = false,
  });

  RequestModel copyWith({
    String? id,
    String? customerName,
    String? customerAvatar,
    String? serviceType,
    String? date,
    String? time,
    String? address,
    double? price,
    String? status,
    bool? isUrgent,
  }) {
    return RequestModel(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      serviceType: serviceType ?? this.serviceType,
      date: date ?? this.date,
      time: time ?? this.time,
      address: address ?? this.address,
      price: price ?? this.price,
      status: status ?? this.status,
      isUrgent: isUrgent ?? this.isUrgent,
    );
  }
}
