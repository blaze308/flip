import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/gift_sent_model.dart';
import '../services/gift_service.dart';
import '../widgets/shimmer_loading.dart';

/// Gifts Tab Widget
/// Displays received gifts in profile
class GiftsTab extends StatefulWidget {
  final String userId;
  final bool isCurrentUser;

  const GiftsTab({
    super.key,
    required this.userId,
    required this.isCurrentUser,
  });

  @override
  State<GiftsTab> createState() => _GiftsTabState();
}

class _GiftsTabState extends State<GiftsTab>
    with AutomaticKeepAliveClientMixin {
  List<GiftSentModel> _gifts = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _totalValue = 0;
  int _totalGifts = 0;
  bool _hasMore = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadGifts();
  }

  Future<void> _loadGifts({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _isLoading = true;
        _gifts = [];
      }
    });

    try {
      final result = widget.isCurrentUser
          ? await GiftService.getReceivedGifts(
              limit: 20,
              skip: loadMore ? _gifts.length : 0,
            )
          : await GiftService.getUserReceivedGifts(
              widget.userId,
              limit: 20,
              skip: loadMore ? _gifts.length : 0,
            );

      if (mounted) {
        final giftsList = result['gifts'] as List;
        final newGifts = giftsList
            .map((g) => GiftSentModel.fromJson(g as Map<String, dynamic>))
            .toList();

        setState(() {
          if (loadMore) {
            _gifts.addAll(newGifts);
            _isLoadingMore = false;
          } else {
            _gifts = newGifts;
            _totalValue = result['totalValue'] as int? ?? 0;
            _totalGifts = result['total'] as int? ?? 0;
            _isLoading = false;
          }
          _hasMore = result['hasMore'] as bool? ?? false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_gifts.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadGifts(),
      color: const Color(0xFF4ECDC4),
      child: CustomScrollView(
        slivers: [
          // Stats Header
          SliverToBoxAdapter(child: _buildStatsHeader()),

          // Gift Grid
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index == _gifts.length) {
                    return _buildLoadMoreButton();
                  }
                  return _buildGiftCard(_gifts[index]);
                },
                childCount: _gifts.length + (_hasMore ? 1 : 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total Gifts', _totalGifts.toString(), '🎁'),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildStatItem(
            'Total Value',
            '${NumberFormat('#,###').format(_totalValue)} 💎',
            '💰',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String icon) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 32),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildGiftCard(GiftSentModel giftSent) {
    return GestureDetector(
      onTap: () => _showGiftDetails(giftSent),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gift Image
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: giftSent.gift?.iconUrl != null
                    ? CachedNetworkImage(
                        imageUrl: giftSent.gift!.iconUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: const Color(0xFF0A0E21),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF4ECDC4),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFF0A0E21),
                          child: const Icon(Icons.card_giftcard,
                              color: Colors.grey, size: 40),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF0A0E21),
                        child: const Icon(Icons.card_giftcard,
                            color: Colors.grey, size: 40),
                      ),
              ),
            ),

            // Gift Info
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    giftSent.gift?.name ?? 'Gift',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        '💎',
                        style: TextStyle(fontSize: 10),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        giftSent.diamondsQuantity.toString(),
                        style: const TextStyle(
                          color: Color(0xFF4ECDC4),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (giftSent.author != null)
                    Text(
                      'From ${giftSent.author!.displayName}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
      );
    }

    return GestureDetector(
      onTap: () => _loadGifts(loadMore: true),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1D1E33),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4ECDC4).withOpacity(0.3),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, color: Color(0xFF4ECDC4), size: 32),
              SizedBox(height: 8),
              Text(
                'Load More',
                style: TextStyle(
                  color: Color(0xFF4ECDC4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 9,
      itemBuilder: (context, index) {
        return ShimmerLoading(
          width: double.infinity,
          height: double.infinity,
          borderRadius: BorderRadius.circular(12),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.card_giftcard,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No gifts yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isCurrentUser
                ? 'Gifts you receive will appear here'
                : 'This user hasn\'t received any gifts yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showGiftDetails(GiftSentModel giftSent) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gift Image
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0E21),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: giftSent.gift?.iconUrl != null
                      ? CachedNetworkImage(
                          imageUrl: giftSent.gift!.iconUrl,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.card_giftcard,
                          color: Colors.grey, size: 60),
                ),
              ),
              const SizedBox(height: 24),

              // Gift Name
              Text(
                giftSent.gift?.name ?? 'Gift',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Details
              _buildDetailRow('From', giftSent.author?.displayName ?? 'Unknown'),
              _buildDetailRow('Value', '${giftSent.diamondsQuantity} 💎'),
              _buildDetailRow('Context', giftSent.contextDisplay),
              _buildDetailRow(
                'Date',
                DateFormat('MMM dd, yyyy • hh:mm a').format(giftSent.createdAt),
              ),

              const SizedBox(height: 24),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

