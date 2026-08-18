import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/legacy_muscle_group_map.dart';
import '../../../../core/constants/muscle_factor_combine.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/exercise.dart';
import '../../application/exercise_bloc.dart';
import '../library_strings.dart';
import 'exercises_tab.dart';
import 'library_chrome.dart';

/// The add/edit exercise panel, rebuilt from frame 12.
///
/// Extracted out of the 1,047-line `exercises_tab.dart` so the panel is not
/// edited inside the list's file. It keeps every key `ExercisesTab` declares
/// for it, because the existing dialog tests resolve them from there.
///
/// Frame 12 is a modal panel over a scrim: `panelTop` fill, square, a 1.5dp
/// `borderStrong` edge and the only shadow in the design system. Its
/// activation sliders get the clearest treatment on the screen — tint track,
/// square handle, multiplier in tabular mono.
class ExerciseDialog extends StatefulWidget {
  const ExerciseDialog({this.exercise, this.onDelete, super.key});

  final Exercise? exercise;

  /// Non-null only in edit mode. Frame 12 draws no delete control because it
  /// is the create panel; the owner's ruling puts delete below save inside
  /// the panel rather than back on the row.
  final VoidCallback? onDelete;

  static const Key deleteButtonKey = ValueKey<String>(
    'library_exercise_dialog_delete_button',
  );
  static const Key saveButtonKey = ValueKey<String>(
    'library_exercise_dialog_save_button',
  );
  static const Key cancelButtonKey = ValueKey<String>(
    'library_exercise_dialog_cancel_button',
  );
  static const Key nameFieldKey = ValueKey<String>(
    'library_exercise_dialog_name_field',
  );

  static Key muscleChipKey(String muscle) =>
      ValueKey<String>('library_exercise_dialog_muscle_chip_$muscle');

  @override
  State<ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<ExerciseDialog> {
  late final TextEditingController _nameController;

  /// Insertion-ordered map: simple-key muscle → activation factor ∈ [0, 1].
  /// The keys serve the same role a `Set<String>` would while the values
  /// drive the factor sliders.
  late final Map<String, double> _selectedMuscleFactors;

  final Uuid _uuid = const Uuid();

  bool get isEditing => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.exercise?.name ?? '');

    // Seed the factor map from the exercise's existing muscle groups.
    // Factors default to 1.0 and are overwritten once [ExerciseFactorsLoaded]
    // arrives from the bloc (see the BlocListener in build()).
    _selectedMuscleFactors = <String, double>{
      for (final String muscle
          in widget.exercise?.muscleGroups ?? const <String>[])
        muscle: 1.0,
    };

    if (isEditing) {
      // Dispatch after the first frame so the BlocProvider is in the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ExerciseBloc>().add(
            LoadExerciseFactorsEvent(widget.exercise!.id),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Called when [ExerciseFactorsLoaded] arrives.
  ///
  /// Keys are 1:1 with the canonical taxonomy, so loaded factors map directly
  /// onto the sliders. Any stray legacy key is canonicalised (and duplicates
  /// collapsed with the MAX rule) defensively before matching.
  void _applyLoadedFactors(Map<String, double> rawFactors) {
    final Map<String, double> canonical = combineCanonicalFactors(
      rawFactors.entries.map(
        (MapEntry<String, double> e) =>
            MapEntry<String, double>(e.key, e.value),
      ),
    );

    setState(() {
      for (final String key in _selectedMuscleFactors.keys.toList()) {
        final double? loaded =
            canonical[LegacyMuscleGroupMap.canonicalizeMuscleKey(key)];
        if (loaded != null) {
          _selectedMuscleFactors[key] = loaded;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExerciseBloc, ExerciseState>(
      listenWhen: (_, ExerciseState current) =>
          current is ExerciseFactorsLoaded &&
          current.exerciseId == widget.exercise?.id,
      listener: (BuildContext context, ExerciseState state) {
        _applyLoadedFactors((state as ExerciseFactorsLoaded).factors);
      },
      child: LibraryPanel(
        content: _buildContent(context),
        footer: _buildFooter(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final bool hasFactors = _selectedMuscleFactors.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isEditing
                ? LibraryStrings.editExercise
                : LibraryStrings.newExercise,
            style: LiftText.titleLarge.copyWith(color: LiftColors.textPrimary),
          ),
          const SizedBox(height: 20),
          const LibraryFieldLabel(LibraryStrings.nameLabel),
          const SizedBox(height: 11),
          TextField(
            key: ExerciseDialog.nameFieldKey,
            controller: _nameController,
            style: LiftText.bodyLarge.copyWith(color: LiftColors.textPrimary),
            decoration: const InputDecoration(
              // Frame 12 draws the name box 41dp tall.
              isDense: true,
              hintText: LibraryStrings.nameHint,
              contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: !isEditing,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          const LibraryFieldLabel(LibraryStrings.muscleGroupsLabel),
          const SizedBox(height: 13),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: MuscleGroups.all
                .map(
                  (String muscle) => LibraryFilterChip(
                    chipKey: ExerciseDialog.muscleChipKey(muscle),
                    height: 30,
                    label: MuscleGroups.getDisplayName(muscle),
                    selected: _selectedMuscleFactors.containsKey(muscle),
                    onTap: () => setState(() {
                      if (_selectedMuscleFactors.containsKey(muscle)) {
                        _selectedMuscleFactors.remove(muscle);
                      } else {
                        _selectedMuscleFactors[muscle] = 1.0;
                      }
                    }),
                  ),
                )
                .toList(growable: false),
          ),
          if (hasFactors) ...<Widget>[
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    LibraryStrings.muscleActivationLabel.toUpperCase(),
                    key: ExercisesTab.factorEditorKey,
                    style: LiftText.labelMedium.copyWith(
                      color: LiftColors.textDim,
                    ),
                  ),
                ),
                TextButton(
                  key: ExercisesTab.resetFactorsButtonKey,
                  onPressed: () => setState(() {
                    for (final String key in _selectedMuscleFactors.keys) {
                      _selectedMuscleFactors[key] = 1.0;
                    }
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: LiftColors.actionTint,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    LibraryStrings.reset.toUpperCase(),
                    style: LiftText.labelMedium.copyWith(
                      color: LiftColors.actionTint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            ..._selectedMuscleFactors.entries.map(
              (MapEntry<String, double> entry) => FactorRow(
                key: ExercisesTab.factorSliderKey(entry.key),
                muscle: entry.key,
                value: entry.value,
                onChanged: (double newValue) => setState(() {
                  _selectedMuscleFactors[entry.key] = newValue;
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final bool isValid =
        _nameController.text.trim().isNotEmpty &&
        _selectedMuscleFactors.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              // Frame 12: CANCEL takes 130dp against SAVE EXERCISE's 179dp
              // across a 318dp content width, i.e. 5:7 with a 10dp gap.
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    key: ExerciseDialog.cancelButtonKey,
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
                    key: ExerciseDialog.saveButtonKey,
                    onPressed: isValid ? _handleSave : null,
                    child: Text(
                      (isEditing
                              ? LibraryStrings.saveChanges
                              : LibraryStrings.saveExercise)
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
                key: ExerciseDialog.deleteButtonKey,
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
                child: const Text('DELETE EXERCISE'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _handleSave() {
    final String name = _nameController.text.trim();
    // Snapshot the factor map so the event carries an immutable copy.
    final Map<String, double> muscleFactors = Map<String, double>.of(
      _selectedMuscleFactors,
    );

    if (isEditing) {
      final Exercise updatedExercise = widget.exercise!.copyWith(
        name: name,
        muscleGroups: muscleFactors.keys.toList(),
      );
      context.read<ExerciseBloc>().add(
        UpdateExerciseEvent(updatedExercise, muscleFactors: muscleFactors),
      );
    } else {
      final Exercise newExercise = Exercise(
        id: _uuid.v4(),
        name: name,
        muscleGroups: muscleFactors.keys.toList(),
        createdAt: DateTime.now(),
      );
      context.read<ExerciseBloc>().add(
        AddExerciseEvent(newExercise, muscleFactors: muscleFactors),
      );
    }

    Navigator.pop(context);
  }
}

// ---------------------------------------------------------------------------
// Per-muscle factor slider row
// ---------------------------------------------------------------------------

/// One muscle's activation row: name, multiplier, slider, hairline.
///
/// Uses its own [State] so dragging only rebuilds this row rather than the
/// whole panel. The parent is notified via [onChanged] when the drag ends.
class FactorRow extends StatefulWidget {
  const FactorRow({
    required this.muscle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String muscle;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  State<FactorRow> createState() => _FactorRowState();
}

class _FactorRowState extends State<FactorRow> {
  late double _localValue;

  @override
  void initState() {
    super.initState();
    _localValue = widget.value;
  }

  @override
  void didUpdateWidget(FactorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when the parent resets all factors.
    if (oldWidget.value != widget.value) {
      _localValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                MuscleGroups.getDisplayName(widget.muscle).toUpperCase(),
                style: LiftText.labelLarge.copyWith(
                  color: LiftColors.textStrong,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            LiftNumber.of(
              _localValue,
              'x',
              LiftText.dataSmall,
              decimals: 2,
              key: ExercisesTab.factorValueKey(widget.muscle),
            ),
          ],
        ),
        SizedBox(
          height: 18,
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: LiftColors.actionTint,
              inactiveTrackColor: LiftColors.effortOff,
              thumbColor: LiftColors.actionTint,
              trackShape: const RectangularSliderTrackShape(),
              thumbShape: const SquareSliderThumb(),
              overlayShape: SliderComponentShape.noOverlay,
              tickMarkShape: SliderTickMarkShape.noTickMark,
            ),
            child: Slider(
              value: _localValue,
              divisions: 20,
              onChanged: (double value) => setState(() => _localValue = value),
              onChangeEnd: widget.onChanged,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: LiftColors.hairline),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Square slider handle (frame 12) — Material has no square thumb.
///
/// Frame 12 measures it 42px square at 3x, i.e. 14dp.
class SquareSliderThumb extends SliderComponentShape {
  const SquareSliderThumb({this.size = 14});

  final double size;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(size, size);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    context.canvas.drawRect(
      Rect.fromCenter(center: center, width: size, height: size),
      Paint()..color = sliderTheme.thumbColor ?? LiftColors.actionTint,
    );
  }
}
