import 'agency_model.dart';

/// Agency Member Model
/// Represents a user's membership in an agency (as owner, agent, or host)
class AgencyMemberModel {
  final String id;
  final String userId;
  final String agencyId;
  final String role; // 'owner', 'agent', 'host'
  final String? invitedByUserId;
  final String? assignedAgentUserId;
  final int invitedAgentsCount;
  final int hostsCount;
  final int totalEarnings;
  final int totalCommission;
  final int hostEarnings;
  final String applicationStatus; // 'pending', 'approved', 'rejected'
  final DateTime? applicationDate;
  final DateTime? approvedDate;
  final DateTime? lastActivityAt;
  final String status; // 'active', 'inactive', 'suspended'
  final DateTime joinedAt;
  final DateTime? leftAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated fields (from backend populate)
  final AgencyModel? agency;
  final Map<String, dynamic>? invitedBy;
  final Map<String, dynamic>? assignedAgent;

  const AgencyMemberModel({
    required this.id,
    required this.userId,
    required this.agencyId,
    required this.role,
    this.invitedByUserId,
    this.assignedAgentUserId,
    this.invitedAgentsCount = 0,
    this.hostsCount = 0,
    this.totalEarnings = 0,
    this.totalCommission = 0,
    this.hostEarnings = 0,
    this.applicationStatus = 'approved',
    this.applicationDate,
    this.approvedDate,
    this.lastActivityAt,
    this.status = 'active',
    required this.joinedAt,
    this.leftAt,
    required this.createdAt,
    required this.updatedAt,
    this.agency,
    this.invitedBy,
    this.assignedAgent,
  });

  factory AgencyMemberModel.fromJson(Map<String, dynamic> json) {
    return AgencyMemberModel(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] is String
          ? json['user']
          : json['user']?['_id'] ?? json['user']?['id'] ?? '',
      agencyId: json['agency'] is String
          ? json['agency']
          : json['agency']?['_id'] ?? json['agency']?['id'] ?? '',
      role: json['role'] ?? 'host',
      invitedByUserId: json['invitedBy'] is String
          ? json['invitedBy']
          : json['invitedBy']?['_id'] ?? json['invitedBy']?['id'],
      assignedAgentUserId: json['assignedAgent'] is String
          ? json['assignedAgent']
          : json['assignedAgent']?['_id'] ?? json['assignedAgent']?['id'],
      invitedAgentsCount: json['invitedAgentsCount'] ?? 0,
      hostsCount: json['hostsCount'] ?? 0,
      totalEarnings: json['totalEarnings'] ?? 0,
      totalCommission: json['totalCommission'] ?? 0,
      hostEarnings: json['hostEarnings'] ?? 0,
      applicationStatus: json['applicationStatus'] ?? 'approved',
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'])
          : null,
      approvedDate: json['approvedDate'] != null
          ? DateTime.parse(json['approvedDate'])
          : null,
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'])
          : null,
      status: json['status'] ?? 'active',
      joinedAt: json['joinedAt'] != null
          ? DateTime.parse(json['joinedAt'])
          : DateTime.now(),
      leftAt: json['leftAt'] != null
          ? DateTime.parse(json['leftAt'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      agency: json['agency'] is Map<String, dynamic>
          ? AgencyModel.fromJson(json['agency'])
          : null,
      invitedBy: json['invitedBy'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['invitedBy'])
          : null,
      assignedAgent: json['assignedAgent'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['assignedAgent'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user': userId,
      'agency': agencyId,
      'role': role,
      'invitedBy': invitedByUserId,
      'assignedAgent': assignedAgentUserId,
      'invitedAgentsCount': invitedAgentsCount,
      'hostsCount': hostsCount,
      'totalEarnings': totalEarnings,
      'totalCommission': totalCommission,
      'hostEarnings': hostEarnings,
      'applicationStatus': applicationStatus,
      'applicationDate': applicationDate?.toIso8601String(),
      'approvedDate': approvedDate?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'status': status,
      'joinedAt': joinedAt.toIso8601String(),
      'leftAt': leftAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isOwner => role == 'owner';
  bool get isAgent => role == 'agent';
  bool get isHost => role == 'host';
  bool get isActive => status == 'active';
  bool get isPending => applicationStatus == 'pending';
  bool get isApproved => applicationStatus == 'approved';
  bool get isRejected => applicationStatus == 'rejected';
}

