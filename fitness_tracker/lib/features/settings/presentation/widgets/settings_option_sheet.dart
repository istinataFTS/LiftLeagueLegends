import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';

class SettingsOption<T> {
  const SettingsOption({
    required this.value,
    required this.title,
    required this.selected,
  });

  final T value;
  final String title;
  final bool selected;
}

class SettingsOptionSheet<T> extends StatelessWidget {
  const SettingsOptionSheet({super.key, required this.options});

  final List<SettingsOption<T>> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map(
              (SettingsOption<T> option) => ListTile(
                title: Text(option.title),
                trailing: option.selected
                    ? const Icon(Icons.check, color: AppTheme.primaryOrange)
                    : null,
                onTap: () => Navigator.of(context).pop(option.value),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}
