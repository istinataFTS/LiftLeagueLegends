// Public voice feature surface. Pages and bootstrap code should import
// from this barrel; the internals (data services, concrete
// implementations) are not re-exported and stay encapsulated.

// Application layer
export 'application/voice_bloc.dart';
export 'application/voice_settings_cubit.dart';

// Presentation — all exports sorted alphabetically within this section.
// Note: VoiceCommandRouter lives at lib/app/voice/voice_command_router.dart
// because it is a cross-feature composition widget; it is intentionally
// not part of this barrel.
export 'presentation/voice_overlay_keys.dart';
export 'presentation/voice_overlay_page.dart';
export 'presentation/voice_settings_page.dart';
export 'presentation/voice_settings_page_keys.dart';
export 'presentation/widgets/voice_budget_indicator.dart';
export 'presentation/widgets/voice_confirmation_card.dart';
export 'presentation/widgets/voice_fab.dart';
export 'presentation/widgets/voice_overlay_status_view.dart';
export 'presentation/widgets/voice_transcript_list.dart';
export 'presentation/widgets/voice_workout_mode_banner.dart';
