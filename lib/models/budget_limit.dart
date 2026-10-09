import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/constants/categories.dart';

class BudgetLimit {
  final ExpenseCategory category;
  double limit;

  BudgetLimit({required this.category, required this.limit});

  Map<String, dynamic> toJson() => {
        'category': category.name,
        'limit': limit,
      };

  factory BudgetLimit.fromJson(Map<String, dynamic> j) {
    final catName = j['category'] as String;
    final cat = kCategories.firstWhere(
      (c) => c.name == catName,
      orElse: () => kCategories.last,
    );
    return BudgetLimit(category: cat, limit: (j['limit'] as num).toDouble());
  }
}
