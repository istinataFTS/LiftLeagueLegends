# LiftLeagueLegends 💪

LiftLeagueLegends is a cross-platform Flutter-based mobile application built to help users track workouts, meals, nutrition, and personal fitness goals in one place.

The project is designed around a clean feature-based structure, scalable architecture, and a cloud-backed data model that uses Supabase as the primary backend while still supporting offline usage.

## Project Overview

LiftLeagueLegends is making sure recording workouts and nutrition is effortless and easy to maintain day by day.

Users can log workouts, record meals, monitor nutrition, create/remove/edit exercises and meals, track progress, set personal targets for training and nutrition, and interact with an AI voice assistant for hands-free logging.

## Platform Support

- **Android** – shipping. Full Gradle/Kotlin/AndroidManifest setup; built and tested in CI.
- **iOS** – not buildable yet. The cross-platform Dart code is iOS-ready, but the Xcode project, Podfile, and asset catalog still need to be scaffolded.

## Technologies Used

- Flutter – cross-platform framework for building the mobile app
- Dart – primary programming language
- flutter_bloc – state management
- sqflite – local database support (offline-first, source of truth synced from Supabase)
- Supabase – primary backend for authenticated users (Auth, Database, Edge Functions)
- OpenAI – AI provider for voice speech-to-text (Whisper) and chat (GPT-4o-mini), called server-side via Supabase Edge Functions
- flutter_tts – on-device text-to-speech for voice replies (no server cost)
- speech_to_text – on-device speech-to-text used as an offline fallback
- sherpa_onnx – on-device wake-word keyword spotting (offline, no access key)
- record – microphone capture for remote Whisper transcription
- permission_handler – runtime microphone and speech permissions
- http – HTTP client for multipart STT uploads
- get_it – dependency injection
- dartz – functional programming utilities
- connectivity_plus – network connectivity detection
- Equatable – simpler state and entity comparisons

## Features

- ✅ Workout logging
- ✅ Meal logging
- ✅ Macro tracking
- ✅ Exercise library management
- ✅ Meal library management
- ✅ History and progress tracking
- ✅ Profile and app session support
- ✅ Voice-based AI assistant for hands-free workout, meal, and nutrition logging
- ✅ On-device wake word and headphone tap-to-wake (Android) for hands-free activation
- ✅ Supabase-powered synchronization for authenticated users
- ✅ Offline fallback support when internet connection is unavailable

## Main App Sections

- Home – overview of progress and fitness activity
- Log – log exercises, meals, and macros
- History – review past activity and tracking data
- Library – manage reusable exercises and meals
- Profile – user and app-related information
- Settings – app preferences and voice configuration

## Voice Assistant

The voice assistant is split between on-device I/O and a single Supabase Edge Function. **An internet connection is currently required** — the assistant is driven by a server-side LLM, so it does not yet function offline.

- **Chat** – GPT-4o-mini behind a Supabase Edge Function, with a server-enforced daily spend cap. This is the brain of the assistant and requires connectivity.
- **Speech-to-text** – remote Whisper for better gym-jargon recognition, with an on-device engine also in place. The on-device path is groundwork for a future fully-offline assistant rather than a runtime fallback today (there's no value in offline STT while the chat model still needs the network).
- **Text-to-speech** – fully on-device, no server call.
- **Wake word** – on-device keyword spotting, offline and with no access key required.

If Supabase is not configured, the voice module degrades gracefully and remote calls return a server failure.

## Planned Features
- Deeper AI integration for personalized workout and nutrition recommendations
- Fully offline voice assistant (on-device LLM) so the bot works without a network connection
- Push notifications for goal reminders and training streaks
- Social features for sharing progress and competing with friends
- Full iOS support (Xcode project, icons, and CI build)
