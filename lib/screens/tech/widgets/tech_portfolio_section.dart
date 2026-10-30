import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TechPortfolioSection extends StatelessWidget {
  final List<String> portfolioImages;
  final VoidCallback onAddImagePressed;

  const TechPortfolioSection({
    super.key,
    required this.portfolioImages,
    required this.onAddImagePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Portfolio & Work Gallery',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            TextButton.icon(
              onPressed: onAddImagePressed,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Photo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (portfolioImages.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  'No portfolio photos uploaded yet.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: portfolioImages.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: portfolioImages[index],
                  fit: BoxFit.cover,
                  memCacheWidth: 300,
                  placeholder: (context, url) => Container(color: Colors.black12),
                  errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              );
            },
          ),
      ],
    );
  }
}
