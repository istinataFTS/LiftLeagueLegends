import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/meal.dart';
import '../../application/meal_bloc.dart';
import '../library_strings.dart';
import 'library_chrome.dart';

/// The add/edit meal panel.
///
/// No frame draws it, so it borrows frame 12's panel wholesale — same
/// [LibraryPanel] shell, same field labels, same footer — rather than
/// inventing a second modal language for the same feature. Its per-field
/// `prefixIcon`s and floating labels go for the same reason frame 12's name
/// field has neither: a label above the box, nothing inside it.
class MealDialog extends StatefulWidget {
  const MealDialog({this.meal, this.onDelete, super.key});

  final Meal? meal;

  /// Non-null only in edit mode; renders as `DELETE MEAL` below save.
  final VoidCallback? onDelete;

  static const Key nameFieldKey = ValueKey<String>(
    'library_meal_dialog_name_field',
  );
  static const Key servingFieldKey = ValueKey<String>(
    'library_meal_dialog_serving_field',
  );
  static const Key saveButtonKey = ValueKey<String>(
    'library_meal_dialog_save_button',
  );
  static const Key cancelButtonKey = ValueKey<String>(
    'library_meal_dialog_cancel_button',
  );
  static const Key deleteButtonKey = ValueKey<String>(
    'library_meal_dialog_delete_button',
  );

  @override
  State<MealDialog> createState() => _MealDialogState();
}

class _MealDialogState extends State<MealDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _servingSizeController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _caloriesController;

  final Uuid _uuid = const Uuid();

  bool get isEditing => widget.meal != null;

  @override
  void initState() {
    super.initState();

    final Meal? meal = widget.meal;

    _nameController = TextEditingController(text: meal?.name ?? '');
    _servingSizeController = TextEditingController(
      text: (meal?.servingSizeGrams ?? 100).toStringAsFixed(0),
    );
    _proteinController = TextEditingController(
      text: (meal?.proteinPer100g ?? 0).toStringAsFixed(0),
    );
    _carbsController = TextEditingController(
      text: (meal?.carbsPer100g ?? 0).toStringAsFixed(0),
    );
    _fatController = TextEditingController(
      text: (meal?.fatPer100g ?? 0).toStringAsFixed(0),
    );
    _caloriesController = TextEditingController(
      text: (meal?.caloriesPer100g ?? 0).toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _servingSizeController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LibraryPanel(
      content: _buildContent(context),
      footer: _buildFooter(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isEditing ? LibraryStrings.editMeal : LibraryStrings.newMeal,
            style: LiftText.titleLarge.copyWith(color: LiftColors.textPrimary),
          ),
          const SizedBox(height: 20),
          _field(
            fieldKey: MealDialog.nameFieldKey,
            label: 'Name',
            hint: 'Chicken bowl',
            controller: _nameController,
            numeric: false,
            autofocus: !isEditing,
          ),
          const SizedBox(height: 18),
          _field(
            fieldKey: MealDialog.servingFieldKey,
            label: 'Serving size (g)',
            controller: _servingSizeController,
          ),
          const SizedBox(height: 18),
          _field(label: 'Protein per 100 g', controller: _proteinController),
          const SizedBox(height: 18),
          _field(label: 'Carbs per 100 g', controller: _carbsController),
          const SizedBox(height: 18),
          _field(label: 'Fat per 100 g', controller: _fatController),
          const SizedBox(height: 18),
          _field(label: 'Calories per 100 g', controller: _caloriesController),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    Key? fieldKey,
    String? hint,
    bool numeric = true,
    bool autofocus = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LibraryFieldLabel(label),
        const SizedBox(height: 11),
        TextField(
          key: fieldKey,
          controller: controller,
          autofocus: autofocus,
          keyboardType: numeric
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          textCapitalization: numeric
              ? TextCapitalization.none
              : TextCapitalization.words,
          style: numeric
              ? LiftText.dataSmall.copyWith(color: LiftColors.textPrimary)
              : LiftText.bodyLarge.copyWith(color: LiftColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 13,
              vertical: 9,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final bool isValid =
        _nameController.text.trim().isNotEmpty &&
        _parseDouble(_servingSizeController.text) > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    key: MealDialog.cancelButtonKey,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    key: MealDialog.saveButtonKey,
                    onPressed: isValid ? _handleSave : null,
                    child: Text(
                      (isEditing
                              ? LibraryStrings.saveChanges
                              : LibraryStrings.saveMeal)
                          .toUpperCase(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (widget.onDelete != null) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                key: MealDialog.deleteButtonKey,
                onPressed: () {
                  Navigator.pop(context);
                  widget.onDelete!();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: LiftColors.error,
                  side: const BorderSide(
                    color: LiftColors.error,
                    width: LiftShape.borderWidth,
                  ),
                ),
                child: const Text('DELETE MEAL'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSave() {
    final Meal nextMeal = Meal(
      id: widget.meal?.id ?? _uuid.v4(),
      name: _nameController.text.trim(),
      servingSizeGrams: _parseDouble(
        _servingSizeController.text,
        fallback: 100,
      ),
      proteinPer100g: _parseDouble(_proteinController.text),
      carbsPer100g: _parseDouble(_carbsController.text),
      fatPer100g: _parseDouble(_fatController.text),
      caloriesPer100g: _parseDouble(_caloriesController.text),
      createdAt: widget.meal?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      syncMetadata: widget.meal?.syncMetadata,
      ownerUserId: widget.meal?.ownerUserId,
    );

    if (isEditing) {
      context.read<MealBloc>().add(UpdateMealEvent(nextMeal));
    } else {
      context.read<MealBloc>().add(AddMealEvent(nextMeal));
    }

    Navigator.pop(context);
  }

  double _parseDouble(String value, {double fallback = 0}) {
    return double.tryParse(value.trim()) ?? fallback;
  }
}
