import 'user_model.dart';

/// Transaction Model
/// Represents a wallet transaction (purchase, gift, reward, etc.)
class TransactionModel {
  final String id;
  final String userId;
  final TransactionType type;
  final CurrencyType currency;
  final int amount;
  final int balanceAfter;
  final UserModel? relatedUser;
  final String? description;
  final PaymentDetails? payment;
  final TransactionStatus status;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.currency,
    required this.amount,
    required this.balanceAfter,
    this.relatedUser,
    this.description,
    this.payment,
    required this.status,
    required this.createdAt,
  });

  /// Factory for creating TransactionModel from JSON
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['_id'] as String? ?? json['id'] as String,
      userId: json['userId'] as String,
      type: _parseTransactionType(json['type'] as String),
      currency: _parseCurrencyType(json['currency'] as String),
      amount: (json['amount'] as num).toInt(),
      balanceAfter: (json['balanceAfter'] as num).toInt(),
      relatedUser: json['relatedUserId'] != null && json['relatedUserId'] is Map
          ? UserModel.fromJson(json['relatedUserId'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String?,
      payment: json['payment'] != null
          ? PaymentDetails.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      status: _parseTransactionStatus(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.value,
      'currency': currency.value,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'description': description,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Helper to parse transaction type from string
  static TransactionType _parseTransactionType(String type) {
    switch (type) {
      case 'purchase':
        return TransactionType.purchase;
      case 'gift_sent':
        return TransactionType.giftSent;
      case 'gift_received':
        return TransactionType.giftReceived;
      case 'vip_purchase':
        return TransactionType.vipPurchase;
      case 'mvp_purchase':
        return TransactionType.mvpPurchase;
      case 'guardian_purchase':
        return TransactionType.guardianPurchase;
      case 'reward':
        return TransactionType.reward;
      case 'refund':
        return TransactionType.refund;
      case 'admin_adjustment':
        return TransactionType.adminAdjustment;
      case 'withdrawal':
        return TransactionType.withdrawal;
      default:
        return TransactionType.purchase;
    }
  }

  /// Helper to parse currency type from string
  static CurrencyType _parseCurrencyType(String currency) {
    switch (currency) {
      case 'coins':
        return CurrencyType.coins;
      case 'diamonds':
        return CurrencyType.diamonds;
      case 'points':
        return CurrencyType.points;
      default:
        return CurrencyType.coins;
    }
  }

  /// Helper to parse transaction status from string
  static TransactionStatus _parseTransactionStatus(String status) {
    switch (status) {
      case 'pending':
        return TransactionStatus.pending;
      case 'completed':
        return TransactionStatus.completed;
      case 'failed':
        return TransactionStatus.failed;
      case 'cancelled':
        return TransactionStatus.cancelled;
      default:
        return TransactionStatus.completed;
    }
  }

  /// Get display icon for transaction type
  String get typeIcon {
    switch (type) {
      case TransactionType.purchase:
        return '💳';
      case TransactionType.giftSent:
        return '🎁';
      case TransactionType.giftReceived:
        return '🎉';
      case TransactionType.vipPurchase:
        return '👑';
      case TransactionType.mvpPurchase:
        return '🏆';
      case TransactionType.guardianPurchase:
        return '🛡️';
      case TransactionType.reward:
        return '⭐';
      case TransactionType.refund:
        return '↩️';
      case TransactionType.adminAdjustment:
        return '⚙️';
      case TransactionType.withdrawal:
        return '💰';
    }
  }

  /// Get display text for transaction type
  String get typeDisplay {
    switch (type) {
      case TransactionType.purchase:
        return 'Purchase';
      case TransactionType.giftSent:
        return 'Gift Sent';
      case TransactionType.giftReceived:
        return 'Gift Received';
      case TransactionType.vipPurchase:
        return 'VIP Purchase';
      case TransactionType.mvpPurchase:
        return 'MVP Purchase';
      case TransactionType.guardianPurchase:
        return 'Guardian Purchase';
      case TransactionType.reward:
        return 'Reward';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.adminAdjustment:
        return 'Adjustment';
      case TransactionType.withdrawal:
        return 'Withdrawal';
    }
  }

  /// Check if transaction is a credit (positive amount)
  bool get isCredit => amount > 0;

  /// Check if transaction is a debit (negative amount)
  bool get isDebit => amount < 0;

  /// Get formatted amount with currency symbol
  String get formattedAmount {
    final absAmount = amount.abs();
    final sign = amount >= 0 ? '+' : '-';
    return '$sign$absAmount ${currency.displayName}';
  }

  /// Get color based on transaction type (for Flutter Color class)
  /// Import 'package:flutter/material.dart' where this is used
  dynamic get colorValue {
    // Returns color codes that can be used with Color()
    if (isCredit) return 0xFF4CAF50; // Green
    if (isDebit) return 0xFFF44336; // Red
    return 0xFF9E9E9E; // Gray
  }
}

/// Payment Details
class PaymentDetails {
  final String method;
  final String? transactionId;
  final double? amount;
  final String? currency;
  final String? status;

  const PaymentDetails({
    required this.method,
    this.transactionId,
    this.amount,
    this.currency,
    this.status,
  });

  factory PaymentDetails.fromJson(Map<String, dynamic> json) {
    return PaymentDetails(
      method: json['method'] as String,
      transactionId: json['transactionId'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'transactionId': transactionId,
      'amount': amount,
      'currency': currency,
      'status': status,
    };
  }
}

/// Transaction Type Enum
enum TransactionType {
  purchase,
  giftSent,
  giftReceived,
  vipPurchase,
  mvpPurchase,
  guardianPurchase,
  reward,
  refund,
  adminAdjustment,
  withdrawal;

  String get value {
    switch (this) {
      case TransactionType.purchase:
        return 'purchase';
      case TransactionType.giftSent:
        return 'gift_sent';
      case TransactionType.giftReceived:
        return 'gift_received';
      case TransactionType.vipPurchase:
        return 'vip_purchase';
      case TransactionType.mvpPurchase:
        return 'mvp_purchase';
      case TransactionType.guardianPurchase:
        return 'guardian_purchase';
      case TransactionType.reward:
        return 'reward';
      case TransactionType.refund:
        return 'refund';
      case TransactionType.adminAdjustment:
        return 'admin_adjustment';
      case TransactionType.withdrawal:
        return 'withdrawal';
    }
  }
}

/// Currency Type Enum
enum CurrencyType {
  coins,
  diamonds,
  points;

  String get value {
    switch (this) {
      case CurrencyType.coins:
        return 'coins';
      case CurrencyType.diamonds:
        return 'diamonds';
      case CurrencyType.points:
        return 'points';
    }
  }

  String get displayName {
    switch (this) {
      case CurrencyType.coins:
        return 'Coins';
      case CurrencyType.diamonds:
        return 'Diamonds';
      case CurrencyType.points:
        return 'Points';
    }
  }

  String get icon {
    switch (this) {
      case CurrencyType.coins:
        return '🪙';
      case CurrencyType.diamonds:
        return '💎';
      case CurrencyType.points:
        return '⭐';
    }
  }
}

/// Transaction Status Enum
enum TransactionStatus {
  pending,
  completed,
  failed,
  cancelled;

  String get value {
    switch (this) {
      case TransactionStatus.pending:
        return 'pending';
      case TransactionStatus.completed:
        return 'completed';
      case TransactionStatus.failed:
        return 'failed';
      case TransactionStatus.cancelled:
        return 'cancelled';
    }
  }
}

