import 'package:flutter/material.dart';
import '../../widgets/booking_card.dart';

class CustomerBookingCardItem extends StatelessWidget {
  final String id;
  final String techName;
  final String serviceName;
  final String location;
  final String description;
  final String dateText;
  final String timeText;
  final String status;
  final String serviceImageUrl;
  final String badgeText;
  final VoidCallback onView;

  const CustomerBookingCardItem({
    super.key,
    required this.id,
    required this.techName,
    required this.serviceName,
    required this.location,
    required this.description,
    required this.dateText,
    required this.timeText,
    required this.status,
    required this.serviceImageUrl,
    required this.badgeText,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return BookingCard(
      techName: techName,
      id: id,
      location: location,
      description: description,
      serviceImageUrl: serviceImageUrl,
      dateText: dateText,
      timeText: timeText,
      status: status,
      serviceName: serviceName,
      badgeText: badgeText,
      onView: onView,
    );
  }
}
