class RemoteSyncRuntimePolicy {
  final bool isSupabaseEnabled;
  final String supabaseUrl;
  final String supabaseAnonKey;

  const RemoteSyncRuntimePolicy({
    required this.isSupabaseEnabled,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  bool get isRemoteSyncConfigured =>
      isSupabaseEnabled &&
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty;
}
