/// Agency Model
/// Represents an agency in the system
class AgencyModel {
  final String id;
  final String name;
  final String agencyId;
  final String ownerId;
  final String? description;
  final double commissionRate; // Percentage (e.g., 12.0)
  final int totalEarnings;
  final int totalCommission;
  final int agentsCount;
  final int hostsCount;
  final String status; // 'active', 'suspended', 'closed'
  final List<String> benefits;
  final List<String> rules;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AgencyModel({
    required this.id,
    required this.name,
    required this.agencyId,
    required this.ownerId,
    this.description,
    this.commissionRate = 12.0,
    this.totalEarnings = 0,
    this.totalCommission = 0,
    this.agentsCount = 0,
    this.hostsCount = 0,
    this.status = 'active',
    this.benefits = const [],
    this.rules = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory AgencyModel.fromJson(Map<String, dynamic> json) {
    return AgencyModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      agencyId: json['agencyId'] ?? '',
      ownerId: json['owner'] is String
          ? json['owner']
          : json['owner']?['_id'] ?? json['owner']?['id'] ?? '',
      description: json['description'],
      commissionRate: (json['commissionRate'] ?? 12.0).toDouble(),
      totalEarnings: json['totalEarnings'] ?? 0,
      totalCommission: json['totalCommission'] ?? 0,
      agentsCount: json['agentsCount'] ?? 0,
      hostsCount: json['hostsCount'] ?? 0,
      status: json['status'] ?? 'active',
      benefits: json['benefits'] != null
          ? List<String>.from(json['benefits'])
          : [],
      rules: json['rules'] != null
          ? List<String>.from(json['rules'])
          : [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'agencyId': agencyId,
      'owner': ownerId,
      'description': description,
      'commissionRate': commissionRate,
      'totalEarnings': totalEarnings,
      'totalCommission': totalCommission,
      'agentsCount': agentsCount,
      'hostsCount': hostsCount,
      'status': status,
      'benefits': benefits,
      'rules': rules,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

