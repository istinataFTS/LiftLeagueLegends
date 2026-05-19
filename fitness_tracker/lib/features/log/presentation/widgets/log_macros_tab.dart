import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/macro_calculator.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../application/nutrition_log_bloc.dart';

class LogMacrosTab extends StatefulWidget {
  final DateTime? initialDate;
  final bool showSuccessFeedback;
  final ValueChanged<DateTime>? onLoggedSuccess;

  const LogMacrosTab({
    super.key,
    this.initialDate,
    this.showSuccessFeedback = true,
    this.onLoggedSuccess,
  });

  @override
  State<LogMacrosTab> createState() => _LogMacrosTabState();
}

class _LogMacrosTabState extends State<LogMacrosTab> {
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _uuid = const Uuid();
  late DateTime _selectedDate;
  bool _logCooldownActive = false;
  Timer? _logCooldownTimer;

  StreamSubscription<NutritionLogUiEffect>? _nutritionEffectsSub;

  @override
  void initState() {
    super.initState();

    _selectedDate = widget.initialDate ?? DateTime.now();

    final nutritionBloc = context.read<NutritionLogBloc>();
    _nutritionEffectsSub = nutritionBloc.effects.listen((effect) {
      if (!mounted) return;

      if (effect is NutritionLogSuccessEffect) {
        if (widget.showSuccessFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(effect.message),
              backgroundColor: AppTheme.successGreen,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }

        widget.onLoggedSuccess?.call(_selectedDate);

        // Retain macro values — short cooldown prevents accidental double-log.
        setState(() => _logCooldownActive = true);
        _logCooldownTimer?.cancel();
        _logCooldownTimer = Timer(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _logCooldownActive = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _nutritionEffectsSub?.cancel();
    _logCooldownTimer?.cancel();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<NutritionLogBloc, NutritionLogState>(
      listener: (context, state) {
        if (state is NutritionLogError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(20),
            ),
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoCard(),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.enterMacros,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildProteinInput(),
                    const SizedBox(height: 16),
                    _buildCarbsInput(),
                    const SizedBox(height: 16),
                    _buildFatsInput(),
                    const SizedBox(height: 20),
                    _buildDatePicker(context),
                    const SizedBox(height: 24),
                    _buildCaloriesPreview(),
                  ],
                ),
              ),
            ),
            _buildLogButton(state),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppTheme.primaryOrange,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Enter macros directly when you don\'t have a meal in your library',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.primaryOrange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProteinInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.proteinGrams,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _proteinController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: AppStrings.enterProtein,
            prefixIcon: const Icon(Icons.egg, color: Colors.blue),
            suffixText: AppStrings.grams,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Text(
          '4 kcal per gram',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }

  Widget _buildCarbsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.carbsGrams,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _carbsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: AppStrings.enterCarbs,
            prefixIcon: const Icon(Icons.grain, color: Colors.green),
            suffixText: AppStrings.grams,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Text(
          '4 kcal per gram',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }

  Widget _buildFatsInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppStrings.fatsGrams,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _fatsController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          decoration: InputDecoration(
            hintText: AppStrings.enterFats,
            prefixIcon: const Icon(Icons.water_drop, color: Colors.orange),
            suffixText: AppStrings.grams,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        const SizedBox(height: 4),
        Text(
          '9 kcal per gram',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Log Date',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaloriesPreview() {
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fats = double.tryParse(_fatsController.text) ?? 0.0;

    final calories = MacroCalculator.calculateCalories(
      protein: protein,
      carbs: carbs,
      fat: fats,
    );

    final hasAnyInput = protein > 0 || carbs > 0 || fats > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasAnyInput
            ? AppTheme.primaryOrange.withValues(alpha: 0.1)
            : AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasAnyInput
              ? AppTheme.primaryOrange.withValues(alpha: 0.3)
              : AppTheme.borderDark,
          width: hasAnyInput ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_fire_department,
                color: hasAnyInput ? AppTheme.primaryOrange : AppTheme.textDim,
                size: 32,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.totalCalories,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: hasAnyInput
                          ? AppTheme.primaryOrange
                          : AppTheme.textMedium,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${calories.round()} ${AppStrings.kcal}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: hasAnyInput
                          ? AppTheme.primaryOrange
                          : AppTheme.textDim,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasAnyInput) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppStrings.autocalculated,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.borderDark),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroBreakdown(
                  label: AppStrings.protein,
                  grams: protein,
                  calories: protein * 4,
                  color: Colors.blue,
                ),
                _buildMacroBreakdown(
                  label: AppStrings.carbs,
                  grams: carbs,
                  calories: carbs * 4,
                  color: Colors.green,
                ),
                _buildMacroBreakdown(
                  label: AppStrings.fats,
                  grams: fats,
                  calories: fats * 9,
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroBreakdown({
    required String label,
    required double grams,
    required double calories,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          '${grams.toStringAsFixed(1)}g',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMedium, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '${calories.round()} kcal',
          style: const TextStyle(color: AppTheme.textDim, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLogButton(NutritionLogState state) {
    final isLoading = state is NutritionLogLoading;
    final protein = double.tryParse(_proteinController.text) ?? 0.0;
    final carbs = double.tryParse(_carbsController.text) ?? 0.0;
    final fats = double.tryParse(_fatsController.text) ?? 0.0;
    final canLog =
        (protein > 0 || carbs > 0 || fats > 0) && !_logCooldownActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.borderDark, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (canLog && !isLoading) ? _handleLogMacros : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    AppStrings.logMacrosButton,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryOrange,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textLight,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _handleLogMacros() {
    final protein = double.parse(
      _proteinController.text.isEmpty ? '0' : _proteinController.text,
    );
    final carbs = double.parse(
      _carbsController.text.isEmpty ? '0' : _carbsController.text,
    );
    final fats = double.parse(
      _fatsController.text.isEmpty ? '0' : _fatsController.text,
    );

    final nutritionLog = NutritionLog(
      id: _uuid.v4(),
      mealId: null,
      mealName: 'Direct Macro Entry',
      gramsConsumed: null,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fats,
      calories: MacroCalculator.calculateCalories(
        protein: protein,
        carbs: carbs,
        fat: fats,
      ),
      loggedAt: _combineDateWithCurrentTime(_selectedDate),
      createdAt: DateTime.now(),
    );

    context.read<NutritionLogBloc>().add(AddNutritionLogEvent(nutritionLog));
  }

  DateTime _combineDateWithCurrentTime(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      date.year,
      date.month,
      date.day,
      now.hour,
      now.minute,
      now.second,
      now.millisecond,
      now.microsecond,
    );
  }
}
