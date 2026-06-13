import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'সুদ / মুনাফা ক্যালকুলেটর',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const CalculatorScreen(),
    );
  }
}

// ─── UNIT ENUM ────────────────────────────────────────────────────────────────

enum AmountUnit { thousands, lacs, crores }

extension AmountUnitExt on AmountUnit {
  String get bnLabel {
    switch (this) {
      case AmountUnit.thousands:
        return 'হাজার';
      case AmountUnit.lacs:
        return 'লাখ';
      case AmountUnit.crores:
        return 'কোটি';
    }
  }

  String get enLabel {
    switch (this) {
      case AmountUnit.thousands:
        return 'Thousand';
      case AmountUnit.lacs:
        return 'Lac';
      case AmountUnit.crores:
        return 'Crore';
    }
  }

  String get suffixLabel {
    switch (this) {
      case AmountUnit.thousands:
        return '৳/হাজার/মাস';
      case AmountUnit.lacs:
        return '৳/লাখ/মাস';
      case AmountUnit.crores:
        return '৳/কোটি/মাস';
    }
  }

  String get commissionHint {
    switch (this) {
      case AmountUnit.thousands:
        return 'যেমন: 10 (প্রতি হাজারে)';
      case AmountUnit.lacs:
        return 'যেমন: 1000 (প্রতি লাখে)';
      case AmountUnit.crores:
        return 'যেমন: 100000 (প্রতি কোটিতে)';
    }
  }

  /// Multiplier to convert "rate per this unit" → "rate per lac"
  /// e.g. per-thousand rate × 100 = per-lac equivalent
  double get toLacMultiplier {
    switch (this) {
      case AmountUnit.thousands:
        return 100.0; // 1 lac = 100 thousands
      case AmountUnit.lacs:
        return 1.0;
      case AmountUnit.crores:
        return 0.01; // 1 lac = 0.01 crores
    }
  }

  Color get badgeColor {
    switch (this) {
      case AmountUnit.thousands:
        return const Color(0xFF00838F);
      case AmountUnit.lacs:
        return const Color(0xFF2E7D32);
      case AmountUnit.crores:
        return const Color(0xFF6A1B9A);
    }
  }

  IconData get badgeIcon {
    switch (this) {
      case AmountUnit.thousands:
        return Icons.looks_3_outlined;
      case AmountUnit.lacs:
        return Icons.looks_6_outlined;
      case AmountUnit.crores:
        return Icons.filter_7_outlined;
    }
  }
}

/// Detect unit from raw numeric value
AmountUnit detectUnit(double amount) {
  if (amount >= 10000000) return AmountUnit.crores; // ≥ 1 crore
  if (amount >= 100000) return AmountUnit.lacs; // ≥ 1 lac
  return AmountUnit.thousands;
}

// ─── SCREEN ───────────────────────────────────────────────────────────────────

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {
  DateTime? startDate;
  DateTime? endDate;
  final amountController = TextEditingController();
  final commissionController = TextEditingController();
  CalculationResult? result;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Auto unit detection state ──
  AmountUnit _detectedUnit = AmountUnit.lacs;
  bool _hasAmount = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final raw = amountController.text.replaceAll(',', '').trim();
    final value = double.tryParse(raw);
    if (value != null && value > 0) {
      final detected = detectUnit(value);
      if (detected != _detectedUnit || !_hasAmount) {
        setState(() {
          _detectedUnit = detected;
          _hasAmount = true;
          result = null; // reset result on amount change
        });
      }
    } else {
      if (_hasAmount) {
        setState(() {
          _hasAmount = false;
          _detectedUnit = AmountUnit.lacs;
          result = null;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    amountController.removeListener(_onAmountChanged);
    amountController.dispose();
    commissionController.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (startDate ?? now) : (endDate ?? now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1B5E20),
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          startDate = picked;
        else
          endDate = picked;
        result = null;
      });
    }
  }

  void calculate() {
    if (startDate == null || endDate == null) {
      _showError('অনুগ্রহ করে শুরু ও শেষ তারিখ নির্বাচন করুন।');
      return;
    }
    if (!endDate!.isAfter(startDate!)) {
      _showError('শেষ তারিখ অবশ্যই শুরু তারিখের পরে হতে হবে।');
      return;
    }
    final amountText = amountController.text.trim();
    final commissionText = commissionController.text.trim();
    if (amountText.isEmpty || commissionText.isEmpty) {
      _showError('অনুগ্রহ করে পরিমাণ ও কমিশন/সুদ হার লিখুন।');
      return;
    }

    final double? amount = double.tryParse(amountText.replaceAll(',', ''));
    final double? commissionPerUnit = double.tryParse(
      commissionText.replaceAll(',', ''),
    );

    if (amount == null || amount <= 0) {
      _showError('সঠিক পরিমাণ লিখুন।');
      return;
    }
    if (commissionPerUnit == null || commissionPerUnit <= 0) {
      _showError('সঠিক কমিশন/সুদ হার লিখুন।');
      return;
    }

    // ── Normalize: convert rate to per-lac equivalent ──
    final double commissionPerLac =
        commissionPerUnit * _detectedUnit.toLacMultiplier;

    final totalDays = endDate!.difference(startDate!).inDays;

    // ── Full months between dates ──
    // A "full month" means the same day-of-month is reached in the later month.
    // e.g. Jan 15 → Mar 20 = 2 full months + 5 remaining days
    final totalMonths = _monthsBetween(startDate!, endDate!);
    final years = totalMonths ~/ 12;
    final remainingMonths = totalMonths % 12;

    // Date after consuming all full months
    final afterFullMonths = _addMonths(startDate!, totalMonths);
    // Remaining days = days between that date and endDate
    final remainingDays = endDate!.difference(afterFullMonths).inDays;

    final double lacCount = amount / 100000;

    // Monthly interest on the principal
    final double monthlyInterest = lacCount * commissionPerLac;

    // Daily interest = monthly / 30 (standard banking convention)
    final double dailyInterest = monthlyInterest / 30;

    // Total interest = (full months × monthly rate) + (remaining days × daily rate)
    final double totalInterest =
        (monthlyInterest * totalMonths) + (dailyInterest * remainingDays);

    final double totalCash = amount + totalInterest;
    final double yearlyInterest = monthlyInterest * 12;

    // Per-unit interest (monthly) — reference table
    final double interestPer1000 = (1000 / 100000) * commissionPerLac;
    final double interestPerLac = commissionPerLac;
    final double interestPer10Lac = 10 * commissionPerLac;
    final double interestPerCrore = 100 * commissionPerLac;

    setState(() {
      result = CalculationResult(
        totalDays: totalDays,
        totalMonths: totalMonths,
        years: years,
        remainingMonths: remainingMonths,
        remainingDays: remainingDays,
        mainCash: amount,
        totalInterest: totalInterest,
        totalCash: totalCash,
        monthlyInterest: monthlyInterest,
        yearlyInterest: yearlyInterest,
        dailyInterest: dailyInterest,
        interestPer1000: interestPer1000,
        interestPerLac: interestPerLac,
        interestPer10Lac: interestPer10Lac,
        interestPerCrore: interestPerCrore,
        commissionRate: commissionPerLac,
        detectedUnit: _detectedUnit,
        commissionPerUnit: commissionPerUnit,
      );
    });
    _animController.reset();
    _animController.forward();
  }

  int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  DateTime _addMonths(DateTime date, int months) {
    return DateTime(
      date.year + months ~/ 12,
      date.month + months % 12,
      date.day,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'সুদ / মুনাফা ক্যালকুলেটর',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Interest & Profit Calculator',
              style: TextStyle(fontSize: 12, color: Color(0xFFA5D6A7)),
            ),
          ],
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputCard(),
            const SizedBox(height: 16),
            if (result != null)
              FadeTransition(opacity: _fadeAnim, child: _buildResultCard()),
          ],
        ),
      ),
    );
  }

  // ─── INPUT CARD ──────────────────────────────────────────────────────────
  Widget _buildInputCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('📅 তারিখ নির্বাচন', 'Select Date Range'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _datePicker(
                    'শুরুর তারিখ\nStart Date',
                    startDate,
                    () => pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _datePicker(
                    'শেষ তারিখ\nEnd Date',
                    endDate,
                    () => pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionLabel('💰 পরিমাণ ও সুদ হার', 'Amount & Rate'),
            const SizedBox(height: 12),

            // ── Amount field with unit badge ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputField(
                  controller: amountController,
                  label: 'মূল পরিমাণ (টাকা)',
                  hint: 'যেমন: 1000000',
                  icon: Icons.account_balance_wallet_outlined,
                  suffix: '৳',
                ),
                if (_hasAmount) ...[const SizedBox(height: 6)],
              ],
            ),

            const SizedBox(height: 12),

            // ── Commission field — label updates live ──
            _inputField(
              controller: commissionController,
              label: _hasAmount
                  ? 'প্রতি ${_detectedUnit.bnLabel}ে মাসিক সুদ/কমিশন'
                  : 'প্রতি লাখে মাসিক সুদ/কমিশন',
              hint: _detectedUnit.commissionHint,
              icon: Icons.percent_outlined,
              suffix: _detectedUnit.suffixLabel,
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: calculate,
                icon: const Icon(Icons.calculate_outlined, size: 22),
                label: const Text(
                  'হিসাব করুন  /  Calculate',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Animated badge showing detected unit
  Widget _unitDetectionBadge() {
    final unit = _detectedUnit;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: Container(
        key: ValueKey(unit),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: unit.badgeColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: unit.badgeColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 13, color: unit.badgeColor),
            const SizedBox(width: 5),
            Text(
              'স্বয়ংক্রিয় শনাক্ত: ',
              style: TextStyle(
                fontSize: 11,
                color: unit.badgeColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${unit.bnLabel} (${unit.enLabel})',
              style: TextStyle(
                fontSize: 11,
                color: unit.badgeColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '— সুদের হার প্রতি ${unit.bnLabel}ে হিসাব হবে',
              style: TextStyle(
                fontSize: 10,
                color: unit.badgeColor.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── RESULT CARD ─────────────────────────────────────────────────────────
  Widget _buildResultCard() {
    final r = result!;
    final fmt = NumberFormat('#,##,###', 'en_IN');
    final fmtD = NumberFormat('#,##,###.##', 'en_IN');

    return Column(
      children: [
        // ── Unit Detection Info Banner ────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: r.detectedUnit.badgeColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: r.detectedUnit.badgeColor.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                r.detectedUnit.badgeIcon,
                color: r.detectedUnit.badgeColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: r.detectedUnit.badgeColor,
                    ),
                    children: [
                      const TextSpan(text: 'ব্যবহৃত হার: '),
                      TextSpan(
                        text:
                            '৳${fmtD.format(r.commissionPerUnit)} / ${r.detectedUnit.bnLabel} / মাস',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text:
                            '  →  লাখ-সমতুল্য: ৳${fmtD.format(r.commissionRate)}/লাখ/মাস',
                        style: TextStyle(
                          fontSize: 10,
                          color: r.detectedUnit.badgeColor.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ── 1. Duration ──────────────────────────────────────────────────
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: const Color(0xFF1B5E20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  '⏱ মেয়াদকাল / Duration',
                  style: TextStyle(
                    color: Color(0xFFA5D6A7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _durationBox('${r.years}', 'বছর\nYear', Icons.event),
                    _vDivider(),
                    _durationBox(
                      '${r.remainingMonths}',
                      'মাস\nMonth',
                      Icons.date_range,
                    ),
                    _vDivider(),
                    _durationBox(
                      '${r.remainingDays}',
                      'দিন\nDays',
                      Icons.today,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: Colors.white.withOpacity(0.15), height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _durationBox(
                      '${r.totalMonths}',
                      'মোট মাস\nTotal Months',
                      Icons.calendar_month,
                    ),
                    _vDivider(),
                    _durationBox(
                      '${r.totalDays}',
                      'মোট দিন\nTotal Days',
                      Icons.calendar_today,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 2. Financial Summary ─────────────────────────────────────────
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('💵 আর্থিক বিবরণ', 'Financial Summary'),
                const SizedBox(height: 16),
                _moneyRow(
                  'মূল টাকা (Main Cash)',
                  fmt.format(r.mainCash),
                  const Color(0xFF1565C0),
                  Icons.account_balance_wallet,
                ),
                const Divider(height: 20),
                _moneyRow(
                  'মোট মুনাফা / সুদ (Total Interest)',
                  fmt.format(r.totalInterest),
                  const Color(0xFF2E7D32),
                  Icons.trending_up,
                ),
                const Divider(height: 20),
                _moneyRow(
                  'সুদসহ মোট টাকা (Total After Interest)',
                  fmt.format(r.totalCash),
                  const Color(0xFFB71C1C),
                  Icons.paid_outlined,
                  isBig: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 3. Per Period ────────────────────────────────────────────────
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('📊 প্রতি মেয়াদে মুনাফা', 'Interest per Period'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _periodCard(
                        'প্রতিদিন\nPer Day',
                        '৳ ${fmtD.format(r.dailyInterest)}',
                        const Color(0xFFF57F17),
                        Icons.wb_sunny_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _periodCard(
                        'প্রতি মাস\nPer Month',
                        '৳ ${fmt.format(r.monthlyInterest)}',
                        const Color(0xFF1B5E20),
                        Icons.calendar_view_month,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _periodCard(
                        'প্রতি বছর\nPer Year',
                        '৳ ${fmt.format(r.yearlyInterest)}',
                        const Color(0xFF4A148C),
                        Icons.bar_chart,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── 4. Per Unit Interest ─────────────────────────────────────────
        Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('🔢 প্রতি একক মাসিক মুনাফা', ''),
                const SizedBox(height: 4),
                Text(
                  'হার: ৳${fmtD.format(r.commissionRate)} / লাখ / মাস  (Rate: ৳${fmtD.format(r.commissionRate)} per lac/month)',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),
                _unitRow(
                  label: '১,০০০ টাকায়',
                  sublabel: 'Per ৳1,000',
                  amount: r.interestPer1000,
                  fmtD: fmtD,
                  color: const Color(0xFF00838F),
                  icon: Icons.looks_one_outlined,
                ),
                const Divider(height: 20),
                _unitRow(
                  label: '১ লাখ টাকায়',
                  sublabel: 'Per ৳1,00,000',
                  amount: r.interestPerLac,
                  fmtD: fmtD,
                  color: const Color(0xFF2E7D32),
                  icon: Icons.looks_two_outlined,
                ),
                const Divider(height: 20),
                _unitRow(
                  label: '১০ লাখ টাকায়',
                  sublabel: 'Per ৳10,00,000',
                  amount: r.interestPer10Lac,
                  fmtD: fmtD,
                  color: const Color(0xFF1565C0),
                  icon: Icons.filter_9_plus_outlined,
                ),
                const Divider(height: 20),
                _unitRow(
                  label: '১ কোটি টাকায়',
                  sublabel: 'Per ৳1,00,00,000',
                  amount: r.interestPerCrore,
                  fmtD: fmtD,
                  color: const Color(0xFF6A1B9A),
                  icon: Icons.monetization_on_outlined,
                  isBig: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─── WIDGETS ─────────────────────────────────────────────────────────────

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    final fmt = DateFormat('dd MMM yyyy');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(
            color: date != null
                ? const Color(0xFF2E7D32)
                : const Color(0xFFBDBDBD),
          ),
          borderRadius: BorderRadius.circular(10),
          color: date != null
              ? const Color(0xFFE8F5E9)
              : const Color(0xFFFAFAFA),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: date != null
                    ? const Color(0xFF2E7D32)
                    : Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: date != null ? const Color(0xFF2E7D32) : Colors.grey,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    date != null ? fmt.format(date) : 'নির্বাচন করুন',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: date != null
                          ? const Color(0xFF1B5E20)
                          : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
        suffixText: suffix,
        suffixStyle: const TextStyle(
          color: Color(0xFF2E7D32),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: const Color(0xFFF9FBF9),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1B5E20), width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF388E3C)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _durationBox(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF81C784), size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF81C784),
            fontSize: 10,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 50,
    color: const Color(0xFF2E7D32).withOpacity(0.4),
  );

  Widget _moneyRow(
    String label,
    String value,
    Color color,
    IconData icon, {
    bool isBig = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '৳ $value',
                style: TextStyle(
                  fontSize: isBig ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _unitRow({
    required String label,
    required String sublabel,
    required double amount,
    required NumberFormat fmtD,
    required Color color,
    required IconData icon,
    bool isBig = false,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '৳ ${fmtD.format(amount)}',
              style: TextStyle(
                fontSize: isBig ? 18 : 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              'প্রতি মাসে',
              style: TextStyle(fontSize: 9, color: Colors.grey[400]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _periodCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String bn, String en) {
    return Row(
      children: [
        Text(
          bn,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B5E20),
          ),
        ),
      ],
    );
  }
}

// ─── MODEL ───────────────────────────────────────────────────────────────────

class CalculationResult {
  final int totalDays;
  final int totalMonths;
  final int years;
  final int remainingMonths;
  final int remainingDays;
  final double mainCash;
  final double totalInterest;
  final double totalCash;
  final double monthlyInterest;
  final double yearlyInterest;
  final double dailyInterest;
  final double interestPer1000;
  final double interestPerLac;
  final double interestPer10Lac;
  final double interestPerCrore;
  final double commissionRate; // always per-lac
  final AmountUnit detectedUnit;
  final double commissionPerUnit; // as entered by user

  CalculationResult({
    required this.totalDays,
    required this.totalMonths,
    required this.years,
    required this.remainingMonths,
    required this.remainingDays,
    required this.mainCash,
    required this.totalInterest,
    required this.totalCash,
    required this.monthlyInterest,
    required this.yearlyInterest,
    required this.dailyInterest,
    required this.interestPer1000,
    required this.interestPerLac,
    required this.interestPer10Lac,
    required this.interestPerCrore,
    required this.commissionRate,
    required this.detectedUnit,
    required this.commissionPerUnit,
  });
}
