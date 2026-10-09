import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:budget_buddy/services/budget_advisor.dart';
import 'package:budget_buddy/services/receipt_scanner.dart';

/// Optional Gemini rewording of [BudgetAdvisor] tips, using the same
/// bring-your-own key as receipt scanning. The advisor decides *what* to say;
/// the model only makes it sound friendlier and more personal. Any failure
/// returns null so callers fall back to the on-device wording.
class AdvisorAi {
  static final _cache = <String, List<String>>{};

  static Map<String, dynamic> buildRequestBody(
      List<AdvisorTip> tips, String userName) {
    final list = [
      for (var i = 0; i < tips.length; i++) '${i + 1}. ${tips[i].message}',
    ].join('\n');
    return {
      'contents': [
        {
          'parts': [
            {
              'text': 'You are Budget Buddy, a warm, concise budgeting coach'
                  '${userName.isEmpty ? '' : ' talking to $userName'}. '
                  'Rewrite each tip below in at most two short sentences. '
                  'Keep every amount and percentage exactly as written, keep '
                  'the same advice, and do not add new facts or numbers. '
                  'Return one rewritten tip per input tip, in order.\n\n$list',
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'ARRAY',
          'items': {'type': 'STRING'},
        },
      },
    };
  }

  /// Extracts the rewritten tips, or null if the shape doesn't match.
  static List<String>? parseResponse(Map<String, dynamic> body, int expected) {
    try {
      final parts = ((body['candidates'] as List).first as Map)['content']
          ['parts'] as List;
      final decoded = jsonDecode((parts.first as Map)['text'] as String);
      if (decoded is! List || decoded.length != expected) return null;
      final out = decoded.map((e) => (e as String).trim()).toList();
      return out.any((s) => s.isEmpty) ? null : out;
    } catch (_) {
      return null;
    }
  }

  /// Rewritten messages for [tips], or null if unavailable (no key, offline,
  /// quota, malformed reply). Results are cached per set of tips.
  static Future<List<String>?> rewrite(
    List<AdvisorTip> tips, {
    String userName = '',
    http.Client? client,
  }) async {
    if (tips.isEmpty) return null;
    final signature = tips.map((t) => t.message).join('\n');
    final cached = _cache[signature];
    if (cached != null) return cached;

    final apiKey = await ReceiptScanner.getApiKey();
    if (apiKey == null) return null;

    final httpClient = client ?? http.Client();
    try {
      final body = jsonEncode(buildRequestBody(tips, userName));
      for (final model in ReceiptScanner.models) {
        final http.Response response;
        try {
          response = await httpClient
              .post(
                Uri.parse('https://generativelanguage.googleapis.com/v1beta/'
                    'models/$model:generateContent?key=$apiKey'),
                headers: {'Content-Type': 'application/json'},
                body: body,
              )
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          return null;
        }
        if (response.statusCode == 404) continue;
        if (response.statusCode != 200) return null;
        final result = parseResponse(
            jsonDecode(response.body) as Map<String, dynamic>, tips.length);
        if (result != null) _cache[signature] = result;
        return result;
      }
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }
}
