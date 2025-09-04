import 'dart:convert';
import 'package:http/http.dart' as http;
import '../secure_storage_service.dart';
import '../../models/graph_session.dart';

class GeminiSender{
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  String? _apiKey;
  String? _selectedModelName;

  // コンストラクタ
  GeminiSender(String apiKey, String modelName, SecureStorageService secureStorageService){
    _apiKey = apiKey;
    _selectedModelName = modelName;
  }

  Future<String> generateResponse(GraphSession session, List<Map<String, dynamic>> chatHistory) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return 'Error: API Key not set.';
    }

    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      return 'Error: Model not selected.';
    }

    try {
      final url = Uri.parse('$_baseUrl/models/$_selectedModelName:generateContent?key=$_apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': chatHistory,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _extractResponseText(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error']['message'] ?? 'Unknown error occurred');
      }
    } catch (e) {
      print('Error generating LLM response: $e');
      if (e.toString().contains('API key not valid')) {
        return 'Error: Invalid API Key. Please check your API Key in settings.';
      }
      return 'Error: Could not connect to LLM. ${e.toString()}';
    }
  }

  // レスポンスからテキストを抽出するユーティリティ
  String _extractResponseText(Map<String, dynamic> data) {
    try {
      final candidates = data['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        for (final cand in candidates) {
          if (cand is Map<String, dynamic>) {
            final content = cand['content'];
            if (content is Map<String, dynamic>) {
              final parts = content['parts'];
              if (parts is List && parts.isNotEmpty) {
                for (final p in parts) {
                  final text = (p is Map<String, dynamic>) ? p['text'] : null;
                  if (text is String && text.trim().isNotEmpty) {
                    return text;
                  }
                }
              }
            }
            // Fallbacks occasionally seen in responses
            final outputText = cand['output_text'];
            if (outputText is String && outputText.trim().isNotEmpty) {
              return outputText;
            }
            final text = cand['text'];
            if (text is String && text.trim().isNotEmpty) {
              return text;
            }
          }
        }
      }
      // Top-level fallbacks
      if (data['output_text'] is String && (data['output_text'] as String).trim().isNotEmpty) {
        return data['output_text'];
      }
      if (data['text'] is String && (data['text'] as String).trim().isNotEmpty) {
        return data['text'];
      }
      return 'Error: No response text from LLM.';
    } catch (e) {
      print('Error extracting response text: $e');
      return 'Error: Invalid response format from LLM.';
    }
  }

}
