import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secure_storage_service.dart';
import '../../models/graph_session.dart';
import 'model_interface.dart';

class LmstudioSender implements ModelInterface {
  static const String _baseUrl = 'http://localhost:1234/v1/chat/completions';
  String? _selectedModelName;

  // コンストラクタ
  LmstudioSender(String apiKey, String modelName, SecureStorageService secureStorageService){
      _selectedModelName = modelName;
  }

  Future<String> generateResponse(GraphSession session, List<Map<String, dynamic>> chatHistory) async {
    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      return 'Error: Model not selected.';
    }

    try {
      final url = Uri.parse(_baseUrl);

      // まずシステムメッセージを追加
      final messages = <Map<String, dynamic>>[

      ];

      // chatHistoryを順番に処理
      for (final history in chatHistory) {
        try {
          final role = history['role'] as String?;
          final parts = history['parts'] as List?;
          
          if (role != null && parts != null && parts.isNotEmpty) {
            final firstPart = parts[0] as Map<String, dynamic>?;
            final text = firstPart?['text'] as String?;
            
            // エラーメッセージを含むcontentは除外
            if (text != null && text.trim().isNotEmpty && !text.contains('Error:')) {
              String openAiRole;
              if (role == 'model') {
                openAiRole = 'assistant';  // model -> assistant
              } else if (role == 'user') {
                openAiRole = 'user';
              } else {
                continue; // 未知のroleはスキップ
              }
              
              messages.add({
                'role': openAiRole,
                'content': text,
              });
            }
          }
        } catch (e) {
          print('Error converting chat history item: $e');
          continue;
        }
      }

      // 最低でも1つのユーザーメッセージが必要（システムメッセージは既に追加済み）
      bool hasUserMessage = messages.any((msg) => msg['role'] == 'user');
      if (!hasUserMessage) {
        return 'Error: No user messages to send to LM Studio.';
      }

      final requestBody = {
        'model': _selectedModelName,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,  // 正の値に修正
        'stream': false,
      };

      print('Sending to LM Studio: ${jsonEncode(requestBody)}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('LM Studio response status: ${response.statusCode}');
      print('LM Studio response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return extractResponseText(data);
      } else {
        print('LM Studio error response: ${response.body}');
        try {
          final error = jsonDecode(response.body);
          throw Exception(error['error']['message'] ?? 'Unknown error occurred');
        } catch (e) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      print('Error generating LLM response: $e');
      return 'Error: Could not connect to LM Studio. ${e.toString()}';
    }
  }

  // レスポンスからテキストを抽出するユーティリティ
  String extractResponseText(Map<String, dynamic> data) {
    try {
      // LM StudioのOpenAI互換レスポンス形式
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final choice = choices[0];
        if (choice is Map<String, dynamic>) {
          final message = choice['message'];
          if (message is Map<String, dynamic>) {
            final content = message['content'];
            if (content is String && content.trim().isNotEmpty) {
              return content;
            }
          }
        }
      }
      return 'Error: No response text from LM Studio.';
    } catch (e) {
      print('Error extracting response text: $e');
      return 'Error: Invalid response format from LM Studio.';
    }
  }

}
