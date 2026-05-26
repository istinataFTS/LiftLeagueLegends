import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseClientProvider {
  final bool isConfigured;

  const SupabaseClientProvider({required this.isConfigured});

  SupabaseClient get client {
    if (!isConfigured) {
      throw StateError('Supabase client requested before it was configured.');
    }

    return Supabase.instance.client;
  }
}
