import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/lift_theme.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../presentation/shared/widgets/lift_effort_selector.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';

/// Edit one logged set: reps, weight, effort.
///
/// ### The crash this dialog used to open with
///
/// Its two actions sat in a bare `Row`, and a `Row` hands its children
/// unbounded width. The app's `elevatedButtonTheme` sets
/// `minimumSize: Size.fromHeight(52)` — which is `Size(double.infinity, 52)` —
/// so the `Update` button demanded infinite width inside a slot that could not
/// bound it, and layout asserted the moment the dialog was built. Editing a
/// set was unreachable in practice while deleting one worked, because delete
/// goes through a plain `AlertDialog` whose `OverflowBar` bounds its actions.
///
/// The actions are `Expanded` now, so the theme's full-width minimum resolves
/// against a real width. Any future full-width `ElevatedButton` dropped into a
/// `Row` in this codebase needs the same treatment.
class EditSetDialog extends StatefulWidget {
  const EditSetDialog({
    required this.workoutSet,
    required this.exercise,
    required this.weightUnit,
    super.key,
  });

  final WorkoutSet workoutSet;
  final Exercise exercise;
  final WeightUnit weightUnit;

  @override
  State<EditSetDialog> createState() => _EditSetDialogState();
}

class _EditSetDialogState extends State<EditSetDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _repsController;
  late final TextEditingController _weightController;
  late int _selectedIntensity;

  WeightUnit? _seededUnit;

  @override
  void initState() {
    super.initState();

    _repsController = TextEditingController(
      text: widget.workoutSet.reps.toString(),
    );
    _weightController = TextEditingController();
    _selectedIntensity = widget.workoutSet.validatedIntensity;
  }

  @override
  void dispose() {
    _repsController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _seedWeightIfNeeded(widget.weightUnit);

    return Dialog(
      backgroundColor: LiftColors.panelTop,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: LiftColors.borderStrong,
          width: LiftShape.borderWidth,
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Edit Set',
                    style: LiftText.titleLarge.copyWith(
                      color: LiftColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.exercise.name.toUpperCase(),
                    style: LiftText.labelMedium.copyWith(
                      color: LiftColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _repsController,
                    decoration: const InputDecoration(
                      labelText: 'Reps',
                      hintText: 'Enter reps',
                    ),
                    keyboardType: TextInputType.number,
                    validator: InputValidators.validateReps,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _weightController,
                    decoration: InputDecoration(
                      labelText: WeightUnitUtils.inputLabel(widget.weightUnit),
                      hintText: WeightUnitUtils.inputHint(widget.weightUnit),
                      // Short enough to fit the dialog's width on a phone;
                      // the long form ellipsised.
                      helperText: 'Always stored in kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: InputValidators.validateWeight,
                  ),
                  const SizedBox(height: 20),
                  LiftEffortSelector(
                    intensity: _selectedIntensity,
                    onChanged: (int value) {
                      setState(() {
                        _selectedIntensity = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleUpdate(widget.weightUnit),
                          child: const Text('UPDATE'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _seedWeightIfNeeded(WeightUnit weightUnit) {
    if (_seededUnit == weightUnit) {
      return;
    }

    _weightController.text =
        WeightUnitUtils.formatInputValueFromStoredKilograms(
          widget.workoutSet.weight,
          weightUnit,
        );
    _seededUnit = weightUnit;
  }

  void _handleUpdate(WeightUnit weightUnit) {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double enteredWeight = double.parse(_weightController.text.trim());

    final WorkoutSet updatedSet = widget.workoutSet.copyWith(
      reps: int.parse(_repsController.text.trim()),
      weight: WeightUnitUtils.toStoredKilograms(enteredWeight, weightUnit),
      intensity: _selectedIntensity,
    );

    context.read<HistoryBloc>().add(UpdateSetEvent(updatedSet));
    Navigator.pop(context);
  }
}
