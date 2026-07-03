import '../../../core/result/result.dart';
import '../../../core/security/input_sanitizer.dart';
import '../../../services/groq_client.dart';

class ChatClient {
  ChatClient(this._groqClient);

  final GroqClient _groqClient;

  Future<Result<String>> sendMessage({
    required String message,
    List<Map<String, dynamic>> history = const [],
    String? attachment,
    String? mimeType,
    String? fileName,
  }) async {
    try {
      final sanitized = InputSanitizer.sanitizeText(message);

      // If there's an attachment, mention it in the message
      String fullMessage = sanitized;
      if (attachment != null) {
        final name = fileName == null
            ? 'an attachment'
            : InputSanitizer.sanitizeText(fileName, maxLength: 160);
        fullMessage =
            '[User sent $name as an attachment]\n\n$sanitized';
      }

      final reply = await _groqClient.sendMessage(
        message: fullMessage,
        history: history,
      );
      return Result.success(reply);
    } catch (e) {
      return Result.failure(NetworkFailure(e.toString()));
    }
  }

  Future<Result<String>> sendDocumentMessage({
    required String documentText,
    required String question,
    List<Map<String, dynamic>> history = const [],
  }) async {
    try {
      final sanitizedQuestion = InputSanitizer.sanitizeText(question);
      final sanitizedDoc = InputSanitizer.sanitizeText(documentText);

      final reply = await _groqClient.sendDocumentMessage(
        documentText: sanitizedDoc,
        question: sanitizedQuestion,
        history: history,
      );
      return Result.success(reply);
    } catch (e) {
      return Result.failure(NetworkFailure(e.toString()));
    }
  }
}