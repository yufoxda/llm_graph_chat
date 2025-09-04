import 'dart:convert';
import 'package:http/http.dart' as http;
import 'secure_storage_service.dart';
import '../models/chat_node.dart';
import '../models/graph_session.dart';
import './connecter/gemini.dart';
import './connecter/lmStudio.dart';

class LlmService {
  // 利用可能なモデルのリスト
  static const Map<String, Map<String, dynamic>> availableModels = {
    'gemini': {
      'base': 'https://generativelanguage.googleapis.com/v1beta',
      'models': [
        'gemini-2.5-pro',
        'gemini-2.5-flash',
        'gemini-2.5-flash-lite-preview-06-17',
        'gemini-2.0-flash-001',
        'gemini-2.0-flash-lite-001',
        'gemini-1.5-pro-002',
        'gemini-1.5-flash-002',
        'gemini-1.5-flash-8b-001',
      ],
    },
    'LM studio': {
      'base': 'http://localhost:1234/v1',
      'models': [
        'openai/gpt-oss-20b',
      ],
    },
  };

  // デフォルトモデル
  static const String defaultModel = 'gemini-2.5-flash-lite-preview-06-17';

  final SecureStorageService _secureStorageService;
  String? _apiKey;
  String? _selectedModelName;

  // コンストラクタ
  LlmService(this._secureStorageService);

  List<String> getAvailableModels() {
    return availableModels.values
      .map((v) => v['models'] as List<String>)
      .expand((models) => models)
      .toList();
  }

  Future<void> initialize() async {
    _apiKey = await _secureStorageService.getApiKey();
    _selectedModelName = await _secureStorageService.getSelectedModel();

    if (_selectedModelName == null || _selectedModelName!.isEmpty) {
      _selectedModelName = defaultModel;
      await _secureStorageService.saveSelectedModel(defaultModel);
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      print('API Key not found. Please set the API Key.');
    } else {
      print('LLM Service Initialized with model: $_selectedModelName');
    }
  }

  Future<String> generateResponse(GraphSession session, ChatNode currentNode) async {
    final chatHistory = _buildChatHistory(session, currentNode);
    
    // 選択されたモデルに基づいて適切なSenderを選択
    if (_selectedModelName != null) {
      // Geminiモデルかどうかをチェック
      final geminiModels = availableModels['gemini']?['models'] as List<String>?;
      if (geminiModels != null && geminiModels.contains(_selectedModelName)) {
        final geminiSender = GeminiSender(_apiKey!, _selectedModelName!, _secureStorageService);
        return await geminiSender.generateResponse(session, chatHistory);
      }
      
      // LM Studioモデルかどうかをチェック
      final lmStudioModels = availableModels['LM studio']?['models'] as List<String>?;
      if (lmStudioModels != null && lmStudioModels.contains(_selectedModelName)) {
        final lmStudioSender = LmstudioSender(_apiKey ?? '', _selectedModelName!, _secureStorageService);
        return await lmStudioSender.generateResponse(session, chatHistory);
      }
    }
    
    // デフォルトはGeminiを使用
    final geminiSender = GeminiSender(_apiKey!, _selectedModelName!, _secureStorageService);
    return await geminiSender.generateResponse(session, chatHistory);
  }
// チャット履歴を構築するユーティリティ
  List<Map<String, dynamic>> _buildChatHistory(GraphSession session, ChatNode currentNode) {
    final history = <Map<String, dynamic>>[];
    ChatNode? node = currentNode;
    final nodeMap = {for (var n in session.nodes) n.id: n};

    // チャット履歴を構築（新しい形式に合わせる）
    while (node != null) {
      if (node.llmOutput.isNotEmpty) {
        history.insert(0, {
          'parts': [{'text': node.llmOutput}],
          'role': 'model'
        });
      }

      history.insert(0, {
        'parts': [{'text': node.userInput}],
        'role': 'user'
      });

      node = node.parentId != null ? nodeMap[node.parentId] : null;
    }

    return history;
  }
}
