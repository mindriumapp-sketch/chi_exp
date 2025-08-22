// main_llm.dart
// Drop-in LLM 클라이언트 (OpenAI Chat Completions 기반)
// -----------------------------------------------
// ✅ 기능
// - 단건 요청 (await) / 스트리밍(Stream<String>) 모두 지원
// - 시스템 프롬프트 + 대화 히스토리 지원
// - 함수형 유틸 (요약/감정 다양성 피드백 예시)
// - 네트워크/응답 에러를 명확한 예외로 래핑
// - 테스트용 main() 데모 포함 (Flutter/CLI 모두 동작)
// -----------------------------------------------
// 📦 의존성 (pubspec.yaml)
//   dependencies:
//     http: ^1.2.1
//
// 🔐 키/환경설정 (권장)
//   --dart-define=OPENAI_API_KEY=sk-xxxx
//   --dart-define=OPENAI_MODEL=gpt-4o-mini  // 미지정 시 기본값 사용
//   --dart-define=OPENAI_BASE_URL=https://api.openai.com  // 프록시/엔터프라이즈 환경에서 변경 가능
// -----------------------------------------------

import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // ✅ debugPrint 사용 가능하게 됨


/// OpenAI Chat Roles
enum ChatRole { system, user, assistant }

/// 대화 메시지 모델
class ChatMessage {
  final ChatRole role;
  final String content;
  const ChatMessage(this.role, this.content);

  Map<String, dynamic> toJson() => {
        'role': _roleToString(role),
        'content': content,
      };

  static String _roleToString(ChatRole r) {
    switch (r) {
      case ChatRole.system:
        return 'system';
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
    }
  }
}

/// LLM 호출 시 던지는 예외
class LlmException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;
  LlmException(this.message, {this.statusCode, this.cause});
  @override
  String toString() => 'LlmException($statusCode): $message';
}

/// OpenAI Chat Completions 클라이언트
class OpenAiChatClient {
  final String apiKey;
  final String model;
  final Uri completionsUri;
  final http.Client _http;

  OpenAiChatClient({
    String? apiKey,
    String? model,
    String? baseUrl,
    http.Client? httpClient,
  })  : apiKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY'),
        model = (model ?? const String.fromEnvironment('OPENAI_MODEL')).isNotEmpty
            ? (model ?? const String.fromEnvironment('OPENAI_MODEL'))
            : 'gpt-4o-mini',
        completionsUri = Uri.parse(
            '${(baseUrl ?? const String.fromEnvironment('OPENAI_BASE_URL', defaultValue: 'https://api.openai.com')).replaceAll(RegExp(r'/\$'), '')}/v1/chat/completions'),
        _http = httpClient ?? http.Client() {
    if (this.apiKey.isEmpty) {
      throw LlmException('OPENAI_API_KEY가 설정되지 않았습니다. --dart-define=OPENAI_API_KEY=... 로 주입하세요.');
    }
  }

  /// 단건 호출 (스트리밍 아님)
  Future<String> complete({
    required List<ChatMessage> messages,
    double temperature = 0.7,
    int? maxTokens,
    Map<String, dynamic>? extraParams,
  }) async {
    throw UnimplementedError('LLM 호출은 주석 처리됨');
  }

  /// 스트리밍 호출
  Stream<String> stream({
    required List<ChatMessage> messages,
    double temperature = 0.7,
    int? maxTokens,
    Map<String, dynamic>? extraParams,
  }) async* {
    throw UnimplementedError('LLM 스트리밍 호출은 주석 처리됨');
  }

  Future<String> summarizeEmotionDiversity({
    required String journalText,
    required List<String> selectedChips,
  }) async {
    throw UnimplementedError('감정 요약 기능은 주석 처리됨');
  }

  Stream<String> streamAdherenceCoach({
    required String userName,
    required int dayIndex,
    required int totalDays,
    required int lastStreak,
  }) async* {
    throw UnimplementedError('순응성 코치 기능은 주석 처리됨');
  }

  void close() => _http.close();
}

// -------------------
// 간단 데모 (CLI/Flutter 공통)
// -------------------
Future<void> main(List<String> args) async {
  // 🔇 LLM 데모는 현재 비활성화됨
  debugPrint('[main_llm.dart] LLM 관련 데모는 주석 처리됨. UI 테스트용으로만 사용됩니다.');
}
