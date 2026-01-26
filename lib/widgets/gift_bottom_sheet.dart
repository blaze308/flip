import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/gift_model.dart';
import '../services/live_streaming_service.dart';
import '../services/gift_service.dart';
import 'custom_toaster.dart';
import 'gift_payment_dialog.dart';

/// Gift Bottom Sheet
/// Shows available gifts for sending in live streams
class GiftBottomSheet extends StatefulWidget {
  final String liveStreamId;
  final String receiverId;
  final String context;
  final Function(GiftModel gift) onGiftSent;

  const GiftBottomSheet({
    super.key,
    required this.liveStreamId,
    required this.receiverId,
    this.context = 'live',
    required this.onGiftSent,
  });

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<GiftBottomSheet>
    with SingleTickerProviderStateMixin {
  List<GiftModel> _gifts = [];
  bool _isLoading = true;
  GiftModel? _selectedGift;
  int _quantity = 1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGifts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGifts() async {
    try {
      final gifts = await LiveStreamingService.getAvailableGifts();
      if (mounted) {
        setState(() {
          _gifts = gifts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading gifts: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToasterService.showError(context, 'Failed to load gifts');
      }
    }
  }

  List<GiftModel> _getGiftsByCategory(String category) {
    // Categorize gifts by weight/value
    switch (category) {
      case 'Popular':
        // Mid-range gifts (20k-40k)
        return _gifts
            .where((g) => g.weight >= 20000 && g.weight <= 40000)
            .toList();
      case 'Premium':
        // High-value gifts (40k+)
        return _gifts.where((g) => g.weight > 40000).toList();
      case 'All':
      default:
        return _gifts;
    }
  }

  void _onGiftTap(GiftModel gift) {
    setState(() {
      _selectedGift = gift;
      _quantity = 1;
    });
  }

  Future<void> _sendGift() async {
    if (_selectedGift == null) return;

    try {
      setState(() => _isLoading = true);

      // Attempt to send the gift
      final result = await GiftService.sendGift(
        giftId: _selectedGift!.id,
        receiverId: widget.receiverId,
        context: widget.context,
        contextId: widget.liveStreamId,
        quantity: _quantity,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (result['success'] == true) {
          // Gift sent successfully
          widget.onGiftSent(_selectedGift!);
          ToasterService.showSuccess(
            context,
            'Sent ${_selectedGift!.name} x$_quantity',
          );
          Navigator.pop(context);
        } else if (result['insufficientBalance'] == true) {
          // Show payment dialog
          final paymentResult = await showDialog<bool>(
            context: context,
            builder:
                (context) => GiftPaymentDialog(
                  gift: _selectedGift!,
                  receiverId: widget.receiverId,
                  context: widget.context,
                  contextId: widget.liveStreamId,
                  quantity: _quantity,
                  required: result['required'] ?? 0,
                  current: result['current'] ?? 0,
                  shortfall: result['shortfall'] ?? 0,
                ),
          );

          if (paymentResult == true && mounted) {
            // Gift was sent after payment
            widget.onGiftSent(_selectedGift!);
            Navigator.pop(context);
          }
        } else {
          // Other error
          ToasterService.showError(
            context,
            result['message'] ?? 'Failed to send gift',
          );
        }
      }
    } catch (e) {
      print('❌ Error sending gift: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToasterService.showError(context, 'Failed to send gift');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4ECDC4),
                      ),
                    )
                    : _buildGiftGrid(),
          ),
          if (_selectedGift != null) _buildSendSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Send Gift',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(
              Icons.emoji_events_outlined,
              color: Colors.pinkAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/utility/gift-leaderboard');
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFF4ECDC4),
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: Colors.white,
        tabs: const [
          Tab(text: 'Popular'),
          Tab(text: 'Premium'),
          Tab(text: 'Special'),
        ],
      ),
    );
  }

  Widget _buildGiftGrid() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildGiftList(_getGiftsByCategory('popular')),
        _buildGiftList(_getGiftsByCategory('premium')),
        _buildGiftList(_getGiftsByCategory('special')),
      ],
    );
  }

  Widget _buildGiftList(List<GiftModel> gifts) {
    if (gifts.isEmpty) {
      return const Center(
        child: Text('No gifts available', style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = _selectedGift?.id == gift.id;

        return GestureDetector(
          onTap: () => _onGiftTap(gift),
          child: Container(
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? const Color(0xFF4ECDC4).withOpacity(0.2)
                      : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? const Color(0xFF4ECDC4) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Gift image/icon
                CachedNetworkImage(
                  imageUrl: gift.iconUrl,
                  width: 50,
                  height: 50,
                  placeholder:
                      (context, url) => const SizedBox(
                        width: 50,
                        height: 50,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF4ECDC4),
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  errorWidget:
                      (context, url, error) => const Icon(
                        Icons.card_giftcard,
                        color: Color(0xFF4ECDC4),
                        size: 50,
                      ),
                ),
                const SizedBox(height: 4),

                // Gift name
                Text(
                  gift.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),

                // Gift price
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFfcb69f).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond,
                        color: Color(0xFFfcb69f),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${gift.weight}',
                        style: const TextStyle(
                          color: Color(0xFFfcb69f),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSendSection() {
    final totalPrice = (_selectedGift?.weight ?? 0) * _quantity;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity controls
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.white),
                  onPressed: () {
                    if (_quantity > 1) {
                      setState(() => _quantity--);
                    }
                  },
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_quantity',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white),
                  onPressed: () {
                    if (_quantity < 99) {
                      setState(() => _quantity++);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Send button
          Expanded(
            child: ElevatedButton(
              onPressed: _sendGift,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4ECDC4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Send',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.diamond, color: Colors.black, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$totalPrice',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
