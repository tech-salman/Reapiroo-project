import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TechServicesSection extends StatelessWidget {
  final List<Map<String, String>> allAvailableServices;
  final Set<String> selectedServices;
  final ValueChanged<String> onServiceToggle;

  const TechServicesSection({
    super.key,
    required this.allAvailableServices,
    required this.selectedServices,
    required this.onServiceToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Active Services',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 16),
        ...allAvailableServices.map((service) {
          final title = service['title']!;
          final imageUrl = service['imageUrl']!;
          final isChecked = selectedServices.contains(title);
          return GestureDetector(
            onTap: () => onServiceToggle(title),
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF3F4F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 72,
                      height: 56,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      placeholder: (context, url) => Container(color: Colors.black12),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChecked ? Colors.black : Colors.grey.shade400,
                        width: 2,
                      ),
                      color: isChecked ? Colors.black : Colors.transparent,
                    ),
                    child: isChecked
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
