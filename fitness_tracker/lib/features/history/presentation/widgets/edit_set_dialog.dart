import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/input_validators.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../presentation/widgets/intensity_slider_widget.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';

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
      backgroundColor: AppTheme.surfaceDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Edit Set',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.exercise.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                      helperText:
                          'Saved internally in kg for future cloud sync',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: InputValidators.validateWeight,
                  ),
                  const SizedBox(height: 20),
                  IntensitySliderWidget(
                    intensity: _selectedIntensity,
                    onChanged: (int value) {
                      setState(() {
                        _selectedIntensity = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => _handleUpdate(widget.weightUnit),
                        child: const Text('Update'),
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
