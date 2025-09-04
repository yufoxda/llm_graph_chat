import '../secure_storage_service.dart';
import '../../models/graph_session.dart';

abstract class ModelInterface {
  static const String _baseUrl = '';
  String? _apiKey;
  String? _selectedModelName;

  // コンストラクタ
  ModelInterface(String apiKey, String modelName, SecureStorageService secureStorageService) {
    _apiKey = apiKey;
    _selectedModelName = modelName;
  }

  Future<String> generateResponse(GraphSession session, List<Map<String, dynamic>> chatHistory);

  // レスポンスからテキストを抽出するユーティリティ
  String _extractResponseText(Map<String, dynamic> data);
}
