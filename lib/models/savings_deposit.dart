class SavingsDeposit {
  final double amount;
  final DateTime date;
  final String? note;

  SavingsDeposit({required this.amount, required this.date, this.note});

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'date': date.millisecondsSinceEpoch,
        'note': note,
      };

  factory SavingsDeposit.fromJson(Map<String, dynamic> j) => SavingsDeposit(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.fromMillisecondsSinceEpoch(j['date'] as int),
        note: j['note'] as String?,
      );
}
