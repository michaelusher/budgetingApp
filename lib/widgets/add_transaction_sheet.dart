import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:budget_buddy/state/app_state.dart';
import 'package:budget_buddy/models/transaction.dart';
import 'package:budget_buddy/models/expense_category.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/services/receipt_scanner.dart';
import 'package:budget_buddy/services/smart_entry_parser.dart';
import 'package:budget_buddy/theme/app_theme.dart';

class AddTransactionSheet extends StatefulWidget {
  final AppState appState;
  final bool isDialog;
  final Transaction? editing;
  const AddTransactionSheet({
    super.key,
    required this.appState,
    this.isDialog = false,
    this.editing,
  });
  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  final _smartController = TextEditingController();
  late ExpenseCategory _selectedCategory;
  late DateTime _selectedDate;
  late RepeatFrequency _repeat;
  bool _scanning = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editing;
    _titleController = TextEditingController(text: t?.title ?? '');
    _amountController = TextEditingController(
        text: t != null ? t.amount.toStringAsFixed(2) : '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedCategory = t?.category ?? kCategories[0];
    _selectedDate = t?.date ?? DateTime.now();
    _repeat = t?.repeat ?? RepeatFrequency.none;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _smartController.dispose();
    super.dispose();
  }

  /// Re-derives the whole form from the smart line on every keystroke, so the
  /// form always mirrors what's typed (deleting "4.50" clears the amount too).
  void _onSmartChanged(String value) {
    final parsed = SmartEntryParser.parse(value);
    setState(() {
      _titleController.text = parsed.title;
      final amount = parsed.amount;
      _amountController.text = amount == null
          ? ''
          : (amount % 1 == 0
              ? amount.toStringAsFixed(0)
              : amount.toStringAsFixed(2));
      if (parsed.category != null) _selectedCategory = parsed.category!;
      _selectedDate = parsed.date ?? DateTime.now();
      _repeat = parsed.repeat;
    });
  }

  // ── Receipt scanning (optional, user's own free Gemini key) ───────────────

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureApiKey() async {
    // Store builds ship a proxy URL — the key lives server-side and users
    // never need one.
    if (ReceiptScanner.usesProxy) return true;
    if (await ReceiptScanner.getApiKey() != null) return true;
    if (!mounted) return false;
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set up receipt scanning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scanning uses Google\'s free Gemini API with your own key — '
              'no card needed. Create one at aistudio.google.com, then paste '
              'it here. It\'s stored only on this device. Receipt photos are '
              'sent to Google for reading.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                prefixIcon: Icon(Icons.key_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final key = controller.text.trim();
    controller.dispose();
    if (saved != true || key.isEmpty) return false;
    await ReceiptScanner.setApiKey(key);
    return true;
  }

  Future<void> _scanReceipt() async {
    if (!await _ensureApiKey() || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      _showSnack(source == ImageSource.camera
          ? 'Camera not available on this device.'
          : 'Could not open the photo library.');
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _scanning = true);
    try {
      final bytes = await picked.readAsBytes();
      final result = await ReceiptScanner.scan(bytes);
      if (!mounted) return;
      setState(() {
        if (result.merchant.isNotEmpty) _titleController.text = result.merchant;
        final total = result.total;
        if (total != null) {
          _amountController.text = total % 1 == 0
              ? total.toStringAsFixed(0)
              : total.toStringAsFixed(2);
        }
        if (result.category != null) _selectedCategory = result.category!;
        if (result.date != null) _selectedDate = result.date!;
      });
      _showSnack('Receipt scanned — review and save.');
    } on ReceiptScanException catch (e) {
      _showSnack(e.message);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (title.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid title and amount')),
      );
      return;
    }
    final note = _noteController.text.trim().isNotEmpty
        ? _noteController.text.trim()
        : null;

    if (_isEdit) {
      widget.appState.updateTransaction(widget.editing!.copyWith(
        title: title,
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        note: note,
        repeat: _repeat,
      ));
    } else {
      widget.appState.addTransaction(Transaction(
        title: title,
        amount: amount,
        category: _selectedCategory,
        date: _selectedDate,
        note: note,
        repeat: _repeat,
      ));
    }
    Navigator.pop(context);
  }

  void _deleteFromEdit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transaction?'),
        content:
            Text('"${widget.editing!.title}" will be removed permanently.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.appState.removeTransaction(widget.editing!.id);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final teal = theme.colorScheme.primary;

    final dateLabel = _formatDate(_selectedDate);

    final form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.isDialog) ...[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
              ),
              child:
                  Icon(_isEdit ? Icons.edit_rounded : Icons.add_rounded, color: teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isEdit ? 'Edit Expense' : 'Add Expense',
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                  ),
                  Text(
                    _isEdit ? 'Update this transaction' : 'Track a new transaction',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (_isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete',
                color: AppColors.danger,
                onPressed: _deleteFromEdit,
              ),
            if (widget.isDialog)
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (!_isEdit) ...[
          TextField(
            controller: _smartController,
            onChanged: _onSmartChanged,
            decoration: InputDecoration(
              labelText: 'Smart add',
              hintText: 'Try "coffee 4.50 yesterday"',
              prefixIcon: Icon(Icons.auto_awesome_rounded, color: teal),
              suffixIcon: _scanning
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.document_scanner_outlined),
                      tooltip: 'Scan a receipt',
                      onPressed: _scanReceipt,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Type naturally and the form fills itself in — parsed on your '
            'phone, free and private. Or scan a receipt photo.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _titleController,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Description',
            hintText: 'What did you spend on?',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Repeats',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RepeatFrequency.values.map((freq) {
            final selected = _repeat == freq;
            return InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              onTap: () => setState(() => _repeat = freq),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? teal.withValues(alpha: 0.12)
                      : (theme.brightness == Brightness.dark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: selected ? teal : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (freq != RepeatFrequency.none) ...[
                      Icon(Icons.repeat_rounded,
                          size: 14,
                          color: selected
                              ? teal
                              : theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      freq.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? teal
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_repeat != RepeatFrequency.none)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Future ${_repeat.label.toLowerCase()} occurrences will be added automatically.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
        const SizedBox(height: 18),
        Text(
          'Category',
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCategories.map((cat) {
            final selected = _selectedCategory.name == cat.name;
            return InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? cat.color.withValues(alpha: 0.14)
                      : (theme.brightness == Brightness.dark
                          ? AppColors.darkSurfaceElevated
                          : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  border: Border.all(
                    color: selected ? cat.color : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon,
                        size: 16,
                        color: selected
                            ? cat.color
                            : theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 6),
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? cat.color
                            : theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteController,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: Icon(Icons.notes_rounded),
          ),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check_rounded, size: 20),
            label: Text(_isEdit ? 'Save Changes' : 'Add Expense'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );

    if (widget.isDialog) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(child: form),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(child: form),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDate = DateTime(d.year, d.month, d.day);
    if (dDate == today) return 'Today';
    if (dDate == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
