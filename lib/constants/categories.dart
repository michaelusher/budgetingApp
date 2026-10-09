import 'package:flutter/material.dart';
import 'package:budget_buddy/models/expense_category.dart';

const List<ExpenseCategory> kCategories = [
  ExpenseCategory(name: 'Food & Dining', icon: Icons.restaurant_rounded, color: Color(0xFFFF6B6B)),
  ExpenseCategory(name: 'Transport', icon: Icons.directions_car_rounded, color: Color(0xFF4ECDC4)),
  ExpenseCategory(name: 'Shopping', icon: Icons.shopping_bag_rounded, color: Color(0xFFFFBE0B)),
  ExpenseCategory(name: 'Entertainment', icon: Icons.movie_rounded, color: Color(0xFFA78BFA)),
  ExpenseCategory(name: 'Bills & Utilities', icon: Icons.receipt_long_rounded, color: Color(0xFFFF8C42)),
  ExpenseCategory(name: 'Health', icon: Icons.favorite_rounded, color: Color(0xFFFF6392)),
  ExpenseCategory(name: 'Education', icon: Icons.school_rounded, color: Color(0xFF38BDF8)),
  ExpenseCategory(name: 'Other', icon: Icons.more_horiz_rounded, color: Color(0xFF94A3B8)),
];
