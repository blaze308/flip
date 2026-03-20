import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/settings_service.dart';

/// My Feedback Screen
/// Lists user's submitted feedback
class MyFeedbackScreen extends StatefulWidget {
  const MyFeedbackScreen({super.key});

  @override
  State<MyFeedbackScreen> createState() => _MyFeedbackScreenState();
}

class _MyFeedbackScreenState extends State<MyFeedbackScreen> {
  List<Map<String, dynamic>> _feedback = [];
  bool _loading = true;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadFeedback();
  }

  Future<void> _loadFeedback({bool loadMore = false}) async {
    if (loadMore && !_hasMore) return;
    if (loadMore) {
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }

    final result = await SettingsService.getMyFeedback(
      page: loadMore ? _page : 1,
      limit: 20,
    );

    if (mounted) {
      final list = (result['feedback'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final hasMore = pagination?['hasMore'] == true;

      setState(() {
        if (loadMore) {
          _feedback.addAll(list);
          _page++;
        } else {
          _feedback = list;
          _page = 2;
        }
        _hasMore = hasMore;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = date is DateTime ? date : DateTime.tryParse(date.toString());
      return d != null ? DateFormat.yMMMd().add_Hm().format(d) : date.toString();
    } catch (_) {
      return date.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('My Feedback', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
            )
          : _feedback.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback_outlined, size: 80, color: Colors.white.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No feedback yet',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your submitted feedback will appear here',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadFeedback(),
                  color: const Color(0xFF4ECDC4),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    itemCount: _feedback.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _feedback.length) {
                        if (_loadingMore) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF4ECDC4)),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: TextButton(
                              onPressed: () => _loadFeedback(loadMore: true),
                              child: const Text('Load more', style: TextStyle(color: Color(0xFF4ECDC4))),
                            ),
                          ),
                        );
                      }

                      final item = _feedback[index];
                      final subject = item['subject']?.toString() ?? 'Feedback';
                      final message = item['message']?.toString() ?? '';
                      final status = item['status']?.toString() ?? 'pending';
                      final createdAt = item['createdAt'];

                      return Card(
                        color: const Color(0xFF1D1E33),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      subject,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'resolved'
                                          ? Colors.green.withOpacity(0.3)
                                          : status == 'reviewed'
                                              ? Colors.blue.withOpacity(0.3)
                                              : Colors.orange.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (message.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  message,
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                _formatDate(createdAt),
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
