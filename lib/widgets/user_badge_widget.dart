import 'package:flutter/material.dart';
import '../models/user_model.dart';

/// Reusable widget for displaying user badges (Wealth Level, Live Level, VIP, MVP, Guardian)
class UserBadgeWidget extends Widget {
  final UserModel user;
  final BadgeType type;
  final double size;
  final bool showLabel;

  const UserBadgeWidget({
    Key? key,
    required this.user,
    required this.type,
    this.size = 24.0,
    this.showLabel = false,
  }) : super(key: key);

  @override
  Element createElement() => _UserBadgeElement(this);
}

class _UserBadgeElement extends ComponentElement {
  _UserBadgeElement(UserBadgeWidget super.widget);

  @override
  UserBadgeWidget get widget => super.widget as UserBadgeWidget;

  @override
  Widget build() {
    final user = widget.user;
    final type = widget.type;
    final size = widget.size;
    final showLabel = widget.showLabel;

    String? iconPath;
    String? label;
    Color? backgroundColor;

    switch (type) {
      case BadgeType.wealthLevel:
        if (user.hasWealthLevel) {
          iconPath = user.wealthLevelIcon;
          label = 'Lv.${user.wealthLevel}';
          backgroundColor = Colors.amber.withOpacity(0.2);
        }
        break;

      case BadgeType.liveLevel:
        if (user.hasLiveLevel) {
          iconPath = user.liveLevelIcon;
          label = 'Lv.${user.liveLevel}';
          backgroundColor = Colors.purple.withOpacity(0.2);
        }
        break;

      case BadgeType.vip:
        if (user.isVip) {
          iconPath = user.vipIcon;
          label = user.vipTier.toUpperCase();
          backgroundColor = _getVipColor(user.vipTier).withOpacity(0.2);
        }
        break;

      case BadgeType.mvp:
        if (user.isMVP) {
          iconPath = user.mvpIcon;
          label = 'MVP';
          backgroundColor = Colors.deepPurple.withOpacity(0.2);
        }
        break;

      case BadgeType.guardian:
        if (user.hasGuardian) {
          iconPath = user.guardianIcon;
          label = user.guardianType?.toUpperCase();
          backgroundColor = _getGuardianColor(user.guardianType).withOpacity(0.2);
        }
        break;
    }

    // If no badge to show, return empty container
    if (iconPath == null || iconPath.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: showLabel ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : null,
      decoration: showLabel && backgroundColor != null
          ? BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: backgroundColor.withOpacity(0.5),
                width: 1,
              ),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Badge icon
          Image.asset(
            iconPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to colored container if image not found
              return Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.grey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForType(type),
                  size: size * 0.6,
                  color: Colors.white,
                ),
              );
            },
          ),
          // Label (optional)
          if (showLabel && label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getVipColor(String tier) {
    switch (tier) {
      case 'diamond':
        return Colors.cyan;
      case 'super':
        return Colors.orange;
      case 'normal':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  Color _getGuardianColor(String? type) {
    switch (type) {
      case 'king':
        return Colors.deepPurple;
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(BadgeType type) {
    switch (type) {
      case BadgeType.wealthLevel:
        return Icons.monetization_on;
      case BadgeType.liveLevel:
        return Icons.star;
      case BadgeType.vip:
        return Icons.workspace_premium;
      case BadgeType.mvp:
        return Icons.emoji_events;
      case BadgeType.guardian:
        return Icons.shield;
    }
  }
}

/// Badge types
enum BadgeType {
  wealthLevel,
  liveLevel,
  vip,
  mvp,
  guardian,
}

/// Widget to display all user badges in a row
class UserBadgesRow extends StatelessWidget {
  final UserModel user;
  final double badgeSize;
  final bool showLabels;
  final MainAxisAlignment alignment;

  const UserBadgesRow({
    Key? key,
    required this.user,
    this.badgeSize = 20.0,
    this.showLabels = false,
    this.alignment = MainAxisAlignment.start,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    // Add badges in priority order
    if (user.isMVP) {
      badges.add(UserBadgeWidget(
        user: user,
        type: BadgeType.mvp,
        size: badgeSize,
        showLabel: showLabels,
      ));
    }

    if (user.isVip) {
      badges.add(UserBadgeWidget(
        user: user,
        type: BadgeType.vip,
        size: badgeSize,
        showLabel: showLabels,
      ));
    }

    if (user.hasGuardian) {
      badges.add(UserBadgeWidget(
        user: user,
        type: BadgeType.guardian,
        size: badgeSize,
        showLabel: showLabels,
      ));
    }

    if (user.hasWealthLevel) {
      badges.add(UserBadgeWidget(
        user: user,
        type: BadgeType.wealthLevel,
        size: badgeSize,
        showLabel: showLabels,
      ));
    }

    if (user.hasLiveLevel) {
      badges.add(UserBadgeWidget(
        user: user,
        type: BadgeType.liveLevel,
        size: badgeSize,
        showLabel: showLabels,
      ));
    }

    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      alignment: WrapAlignment.start,
      children: badges,
    );
  }
}

