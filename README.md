# LiftLeagueLegends 💪

LiftLeagueLegends is a cross-platform Flutter-based mobile application built to help users track workouts, meals, nutrition, and personal fitness goals in one place.

The project is designed around a clean feature-based structure, scalable architecture, and a cloud-backed data model that uses Supabase as the primary backend while still supporting offline usage.

## Project Overview

LiftLeagueLegends is making sure recording workouts and nutrition is effortless and easy to maintain day by day.

Users can log workouts, record meals, monitor nutrition, create/remove/edit exercises and meals, track progress, set personal targets for training and nutrition, and interact with an AI voice assistant for hands-free logging.

## Technologies Used

- Flutter – cross-platform framework for building the mobile app
- Dart – primary programming language
- flutter_bloc – state management
- sqflite – local database support
- Supabase – primary backend for authenticated users (Auth, Database, Edge Functions)
- OpenAI – AI provider for voice speech-to-text, chat, and text-to-speech
- http – HTTP client for multipart STT uploads and binary TTS downloads
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
- ✅ Personal targets and goal tracking
- ✅ Profile and app session support
- ✅ Voice-based AI assistant for hands-free workout, meal, and nutrition logging
- ✅ Supabase-powered synchronization for authenticated users
- ✅ Offline fallback support when internet connection is unavailable

## Main App Sections

- Home – overview of progress and fitness activity
- Log – log exercises, meals, and macros
- History – review past activity and tracking data
- Library – manage reusable exercises and meals
- Targets – manage training and nutrition goals
- Profile – user and app-related information

## Planned Features
- Deeper AI integration for personalized workout and nutrition recommendations
- Push notifications for goal reminders and training streaks
- Social features for sharing progress and competing with friends

## Developer Reference

- [`fitness_tracker/KNOWN_ISSUES.md`](fitness_tracker/KNOWN_ISSUES.md) — recurring stack gotchas (sync quirks, SQLite migration rules, voice constraints, DI pitfalls, CI tooling); consult before debugging, update after any fix that took >15 minutes
