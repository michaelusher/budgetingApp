import 'package:flutter/material.dart';
import 'package:budget_buddy/models/savings_deposit.dart';
import 'package:budget_buddy/constants/goal_icons.dart';

class SavingsGoal {
  final String name;
  final double target;
  final IconData icon;
  final List<SavingsDeposit> deposits;

  SavingsGoal({
    required this.name,
    required this.target,
    required this.icon,
    List<SavingsDeposit>? deposits,
  }) : deposits = deposits ?? [];

  double get saved => deposits.fold(0.0, (sum, d) => sum + d.amount);
  double get progress => target > 0 ? (saved / target).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'target': target,
        'iconIndex': goalIconIndex(icon),
        'deposits': deposits.map((d) => d.toJson()).toList(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> j) => SavingsGoal(
        name: j['name'] as String,
        target: (j['target'] as num).toDouble(),
        icon: goalIconAt((j['iconIndex'] as int?) ?? 0),
        deposits: (j['deposits'] as List)
            .map((d) => SavingsDeposit.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
