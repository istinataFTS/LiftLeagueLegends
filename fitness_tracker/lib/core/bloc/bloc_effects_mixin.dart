import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

mixin BlocEffectsMixin<State, Effect> on BlocBase<State> {
  final StreamController<Effect> _effectsController =
      StreamController<Effect>.broadcast();

  Stream<Effect> get effects => _effectsController.stream;

  void emitEffect(Effect effect) {
    if (!_effectsController.isClosed) {
      _effectsController.add(effect);
    }
  }

  @override
  Future<void> close() async {
    await _effectsController.close();
    return super.close();
  }
}
