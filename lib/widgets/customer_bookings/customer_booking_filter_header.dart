import 'package:flutter/material.dart';

class CustomerBookingFilterHeader extends StatelessWidget {
  final String selectedStatusFilter;
  final ValueChanged<String?> onFilterChanged;

  const CustomerBookingFilterHeader({
    super.key,
    required this.selectedStatusFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Bookings',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedStatusFilter,
                isDense: true,
                dropdownColor: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(16),
                icon: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                items: const [
                  DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                  DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                  DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                ],
                onChanged: onFilterChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
