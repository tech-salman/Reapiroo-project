import 'package:flutter/material.dart';
import 'package:reapiroo/services/storage_service.dart';
import 'package:reapiroo/services/database_service.dart';

class OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onBid;

  const OfferCard({
    super.key,
    required this.offer,
    required this.onTap,
    required this.onAccept,
    required this.onBid,
  });

  @override
  Widget build(BuildContext context) {
    final techName = offer['techName'] as String? ?? 'Technician';
    final techId = offer['techId'] as String? ?? '';
    final experience = offer['experience'] as String? ?? 'Verified Technician';
    final price = (offer['price'] as num?)?.toDouble() ?? (offer['amount'] as num?)?.toDouble() ?? 0.0;
    final rating = (offer['rating'] as num?)?.toDouble() ?? (offer['techRating'] as num?)?.toDouble() ?? 5.0;
    final reviewCount = (offer['reviewCount'] as num?)?.toInt() ?? 0;
    final initialAvatarUrl = offer['avatarUrl'] as String? ?? offer['techAvatar'] as String? ?? '';
    final senderRole = offer['senderRole'] as String? ?? 'tech';
    final status = offer['status'] as String? ?? 'pending';

    final isCustomerBid = senderRole == 'customer';
    final priceStr = price.toStringAsFixed(0);
    final isLongPrice = priceStr.length >= 4;

    String statusLabel = '';
    Color statusColor = Colors.transparent;
    if (status == 'accepted') {
      statusLabel = 'Offer Accepted';
      statusColor = const Color(0xFF10B981);
    } else if (status == 'declined') {
      statusLabel = 'Counter-bid Declined';
      statusColor = const Color(0xFFEF4444);
    } else if (isCustomerBid) {
      statusLabel = 'Your Counter-bid Sent';
      statusColor = const Color(0xFF3B82F6);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: statusLabel.isNotEmpty
              ? Border.all(color: statusColor, width: 1.5)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: initialAvatarUrl.isNotEmpty ? Future.value(initialAvatarUrl) : DatabaseService().getUniversalUserAvatar(techId),
              builder: (context, snapshot) {
                final avatarUrl = snapshot.data ?? initialAvatarUrl;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: avatarUrl.isNotEmpty
                      ? Image(
                          image: StorageService.getImageProvider(avatarUrl),
                          width: 85,
                          height: 85,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 85,
                            height: 85,
                            color: Colors.grey.shade800,
                            child: const Icon(Icons.person, color: Colors.white, size: 36),
                          ),
                        )
                      : Container(
                          width: 85,
                          height: 85,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.person, color: Colors.white, size: 36),
                        ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          techName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Color(0xFFFFC107), size: 15),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ' ($reviewCount)',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    experience,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (statusLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    crossFadeState: isLongPrice ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    firstChild: Row(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              priceStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Text(
                              'AED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: isCustomerBid ? null : onAccept,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCustomerBid ? Colors.grey.shade700 : Colors.white,
                              foregroundColor: isCustomerBid ? Colors.white38 : Colors.black,
                              disabledBackgroundColor: Colors.grey.shade700,
                              disabledForegroundColor: Colors.white38,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Accept',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: onBid,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE5E5EA),
                              foregroundColor: Colors.black,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Bid',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    secondChild: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              priceStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'AED',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: isCustomerBid ? null : onAccept,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isCustomerBid ? Colors.grey.shade700 : Colors.white,
                                    foregroundColor: isCustomerBid ? Colors.white38 : Colors.black,
                                    disabledBackgroundColor: Colors.grey.shade700,
                                    disabledForegroundColor: Colors.white38,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Accept',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: onBid,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE5E5EA),
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Text(
                                    'Bid',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
