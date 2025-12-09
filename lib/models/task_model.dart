/// Task Model
class TaskModel {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final String category;
  final String? icon;
  final TaskRequirement requirement;
  final TaskRewards rewards;
  final bool isActive;
  final int sortOrder;
  final TaskProgress? userProgress;

  const TaskModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    this.icon,
    required this.requirement,
    required this.rewards,
    required this.isActive,
    required this.sortOrder,
    this.userProgress,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: TaskType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TaskType.daily,
      ),
      category: json['category'] as String,
      icon: json['icon'] as String?,
      requirement: TaskRequirement.fromJson(json['requirement'] as Map<String, dynamic>),
      rewards: TaskRewards.fromJson(json['rewards'] as Map<String, dynamic>),
      isActive: json['isActive'] as bool,
      sortOrder: (json['sortOrder'] as num).toInt(),
      userProgress: json['userProgress'] != null
          ? TaskProgress.fromJson(json['userProgress'] as Map<String, dynamic>)
          : null,
    );
  }

  double get progressPercentage {
    if (userProgress == null) return 0.0;
    return (userProgress!.progress / requirement.target).clamp(0.0, 1.0);
  }

  bool get isCompleted => userProgress?.isCompleted ?? false;
  bool get isClaimed => userProgress?.isClaimed ?? false;
}

enum TaskType {
  daily,
  weekly,
  achievement,
  host,
  live,
  vip,
  party,
}

class TaskRequirement {
  final String action;
  final int target;
  final Map<String, dynamic>? conditions;

  const TaskRequirement({
    required this.action,
    required this.target,
    this.conditions,
  });

  factory TaskRequirement.fromJson(Map<String, dynamic> json) {
    return TaskRequirement(
      action: json['action'] as String,
      target: (json['target'] as num).toInt(),
      conditions: json['conditions'] as Map<String, dynamic>?,
    );
  }
}

class TaskRewards {
  final int coins;
  final int diamonds;
  final int xp;

  const TaskRewards({
    required this.coins,
    required this.diamonds,
    required this.xp,
  });

  factory TaskRewards.fromJson(Map<String, dynamic> json) {
    return TaskRewards(
      coins: (json['coins'] as num).toInt(),
      diamonds: (json['diamonds'] as num).toInt(),
      xp: (json['xp'] as num).toInt(),
    );
  }

  bool get hasRewards => coins > 0 || diamonds > 0 || xp > 0;
}

class TaskProgress {
  final int progress;
  final bool isCompleted;
  final bool isClaimed;
  final DateTime? completedAt;
  final DateTime? claimedAt;

  const TaskProgress({
    required this.progress,
    required this.isCompleted,
    required this.isClaimed,
    this.completedAt,
    this.claimedAt,
  });

  factory TaskProgress.fromJson(Map<String, dynamic> json) {
    return TaskProgress(
      progress: (json['progress'] as num).toInt(),
      isCompleted: json['isCompleted'] as bool,
      isClaimed: json['isClaimed'] as bool,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      claimedAt: json['claimedAt'] != null
          ? DateTime.parse(json['claimedAt'] as String)
          : null,
    );
  }
}

