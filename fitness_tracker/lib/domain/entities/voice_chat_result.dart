import 'voice_message.dart';
import 'voice_tool_call.dart';

/// Union type for the three categories of response from `voice-chat`.
sealed class VoiceChatResult {
  const VoiceChatResult();
}

/// LLM returned a plain text message — speak and add to conversation.
/// A final statement; ends the turn and returns to [VoiceStatus.idle].
final class VoiceChatTextResponse extends VoiceChatResult {
  const VoiceChatTextResponse({required this.message});
  final VoiceMessage message;
}

/// LLM asked a clarifying question (the `clarify` tool). Spoken to the user,
/// then the conversation auto-re-listens for the answer — distinct from
/// [VoiceChatTextResponse], which is a final statement that ends the turn.
/// See redesign-overview.md §3.
final class VoiceChatClarifyResponse extends VoiceChatResult {
  const VoiceChatClarifyResponse({required this.message});
  final VoiceMessage message;
}

/// LLM returned a mutation tool call (log/edit/delete).
/// Requires user confirmation before the client dispatches to a target bloc.
final class VoiceChatMutationCall extends VoiceChatResult {
  const VoiceChatMutationCall({required this.toolCall});
  final VoiceToolCall toolCall;
}

/// LLM returned a query tool call (read-only).
/// Client executes via local use cases, formats result, speaks directly.
/// No confirmation card; no second LLM call.
final class VoiceChatQueryCall extends VoiceChatResult {
  const VoiceChatQueryCall({
    required this.toolCallId,
    required this.toolName,
    required this.args,
  });

  final String toolCallId;
  final String toolName;
  final Map<String, dynamic> args;
}
