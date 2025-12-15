import 'package:flutter/material.dart';
import '../../models/live_stream_model.dart';
import '../../services/token_auth_service.dart';
import '../../widgets/custom_toaster.dart';
import 'agora_video_party_screen_v2.dart';
import 'agora_audio_party_screen.dart';

/// Party Setup Screen
/// Allows users to choose party type and number of seats before starting
class PartySetupScreen extends StatefulWidget {
  final String partyType; // 'video' or 'audio'

  const PartySetupScreen({
    required this.partyType,
    Key? key,
  }) : super(key: key);

  @override
  State<PartySetupScreen> createState() => _PartySetupScreenState();
}

class _PartySetupScreenState extends State<PartySetupScreen> {
  int _selectedSeats = 3; // Default to 3 seats
  bool _isLoading = false;

  // Seat options following TikTok party standards
  static const List<int> SEAT_OPTIONS = [3, 6, 9];
  static const Map<int, String> SEAT_DESCRIPTIONS = {
    3: 'Small party\nQuick & cozy',
    6: 'Medium party\nClassic setup',
    9: 'Large party\nMaximum fun',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create ${widget.partyType == 'video' ? 'Video' : 'Audio'} Party',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Select Number of Seats',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Choose how many people can join your party',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),

              // Seat options list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: SEAT_OPTIONS.length,
                itemBuilder: (context, index) {
                  final seats = SEAT_OPTIONS[index];
                  final isSelected = _selectedSeats == seats;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildSeatOption(
                      seats: seats,
                      isSelected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedSeats = seats;
                        });
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Info section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Party Info',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• You will be the host and occupy seat 0\n'
                      '• Other users can join available seats\n'
                      '• Video/Audio can be toggled anytime\n'
                      '• Party ends when you leave\n'
                      '• Maximum ${_selectedSeats} people at once',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Start button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startParty,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    disabledBackgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Start Party',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeatOption({
    required int seats,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.8),
                    const Color(0xFF8B5CF6).withOpacity(0.8),
                  ],
                )
              : null,
          color: isSelected ? null : const Color(0xFF1A1F3A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Seat info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$seats-Person Party',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      SEAT_DESCRIPTIONS[seats] ?? '',
                      style: TextStyle(
                        color: isSelected ? Colors.white70 : Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startParty() async {
    setState(() => _isLoading = true);

    try {
      final user = TokenAuthService.currentUser;
      if (user == null) {
        ToasterService.showError(context, 'Please login first');
        setState(() => _isLoading = false);
        return;
      }

      // Generate channel ID
      final channelId = DateTime.now().millisecondsSinceEpoch.toString();

      // Create initial live stream model
      final liveStream = LiveStreamModel(
        id: '', // Will be set after creation
        authorId: user.id,
        streamingChannel: channelId,
        liveType: 'party',
        authorUid: int.parse(
          user.id.hashCode.toString().substring(0, 8),
        ),
        partyType: widget.partyType,
        numberOfChairs: _selectedSeats,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        streaming: false,
      );

      // Navigate to appropriate party screen
      if (mounted) {
        if (widget.partyType == 'video') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AgoraVideoPartyScreenV2(
                liveStream: liveStream,
                isHost: true,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AgoraAudioPartyScreen(
                liveStream: liveStream,
                isHost: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error starting party: $e');
      ToasterService.showError(context, 'Failed to start party');
      setState(() => _isLoading = false);
    }
  }
}
