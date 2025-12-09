import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../providers/rewards_providers.dart';
import '../widgets/custom_toaster.dart';
import '../widgets/shimmer_loading.dart';

/// Tasks Screen
/// Displays daily, weekly, and achievement tasks with progress tracking
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _currentFilter;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    setState(() {
      switch (_tabController.index) {
        case 0:
          _currentFilter = null; // All tasks
          break;
        case 1:
          _currentFilter = 'daily';
          break;
        case 2:
          _currentFilter = 'weekly';
          break;
        case 3:
          _currentFilter = 'achievement';
          break;
      }
    });
  }

  Future<void> _claimTask(String taskId) async {
    final result = await ref.read(tasksProvider(_currentFilter).notifier).claimTaskReward(taskId);

    if (mounted) {
      if (result['success'] == true) {
        final rewards = result['rewards'];
        String message = 'Claimed: ';
        if (rewards['coins'] > 0) message += '${rewards['coins']} coins ';
        if (rewards['diamonds'] > 0) message += '${rewards['diamonds']} diamonds ';
        if (rewards['xp'] > 0) message += '${rewards['xp']} XP';

        ToasterService.showSuccess(context, message.trim());
      } else {
        ToasterService.showError(context, result['message'] ?? 'Failed to claim reward');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider(_currentFilter));
    final summaryAsync = ref.watch(taskSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        title: const Text('Tasks', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1D1E33),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4ECDC4),
          labelColor: const Color(0xFF4ECDC4),
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
            Tab(text: 'Achievements'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Card
          summaryAsync.when(
            loading: () => Padding(
              padding: const EdgeInsets.all(16),
              child: ShimmerLoading(
                width: double.infinity,
                height: 80,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            error: (error, stack) => const SizedBox.shrink(),
            data: (summary) {
              if (summary == null) return const SizedBox.shrink();
              return _buildSummaryCard(summary);
            },
          ),

          // Tasks List
          Expanded(
            child: tasksAsync.when(
              loading: () => _buildLoadingState(),
              error: (error, stack) => _buildErrorState(),
              data: (tasks) {
                if (tasks.isEmpty) {
                  return _buildEmptyState();
                }
                return RefreshIndicator(
                  onRefresh: () => ref.read(tasksProvider(_currentFilter).notifier).refresh(),
                  color: const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF1D1E33),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) => _buildTaskCard(tasks[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Map<String, int> summary) {
    final total = summary['totalTasks'] ?? 0;
    final completed = summary['completedTasks'] ?? 0;
    final claimed = summary['claimedTasks'] ?? 0;
    final progress = total > 0 ? completed / total : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4ECDC4), Color(0xFF556270)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Total', total.toString(), Icons.assignment),
              _buildSummaryItem('Completed', completed.toString(), Icons.check_circle),
              _buildSummaryItem('Claimed', claimed.toString(), Icons.card_giftcard),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% Complete',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
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

  Widget _buildTaskCard(TaskModel task) {
    final isCompleted = task.isCompleted;
    final isClaimed = task.isClaimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted && !isClaimed
              ? const Color(0xFF4ECDC4)
              : Colors.grey.withOpacity(0.3),
          width: isCompleted && !isClaimed ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Task Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getTaskCategoryColor(task.category).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getTaskIcon(task.category),
                  color: _getTaskCategoryColor(task.category),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Task Title & Type
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _buildTaskTypeBadge(task.type.name),
                        if (isClaimed) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.check_circle, color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Claimed',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Task Description
          Text(
            task.description,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 12),
          // Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress: ${task.userProgress?.progress ?? 0}/${task.requirement.target}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '${(task.progressPercentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF4ECDC4),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progressPercentage,
                  minHeight: 6,
                  backgroundColor: Colors.grey[800],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : const Color(0xFF4ECDC4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Rewards & Claim Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rewards
              Wrap(
                spacing: 12,
                children: [
                  if (task.rewards.coins > 0)
                    _buildRewardChip(Icons.toll, '${task.rewards.coins}', Colors.amber),
                  if (task.rewards.diamonds > 0)
                    _buildRewardChip(Icons.diamond, '${task.rewards.diamonds}', Colors.cyan),
                  if (task.rewards.xp > 0)
                    _buildRewardChip(Icons.star, '${task.rewards.xp} XP', Colors.purple),
                ],
              ),
              // Claim Button
              if (isCompleted && !isClaimed)
                ElevatedButton(
                  onPressed: () => _claimTask(task.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4ECDC4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Claim',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskTypeBadge(String type) {
    Color color;
    switch (type) {
      case 'daily':
        color = Colors.orange;
        break;
      case 'weekly':
        color = Colors.blue;
        break;
      case 'achievement':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        type.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRewardChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getTaskCategoryColor(String category) {
    switch (category) {
      case 'social':
        return Colors.pink;
      case 'streaming':
        return Colors.red;
      case 'engagement':
        return Colors.orange;
      case 'premium':
        return Colors.amber;
      case 'special':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTaskIcon(String category) {
    switch (category) {
      case 'social':
        return Icons.people;
      case 'streaming':
        return Icons.videocam;
      case 'engagement':
        return Icons.favorite;
      case 'premium':
        return Icons.workspace_premium;
      case 'special':
        return Icons.star;
      default:
        return Icons.assignment;
    }
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerLoading(
          width: double.infinity,
          height: 150,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Failed to load tasks',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => ref.read(tasksProvider(_currentFilter).notifier).refresh(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4ECDC4),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No tasks available',
            style: TextStyle(color: Colors.grey[400], fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new tasks!',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

