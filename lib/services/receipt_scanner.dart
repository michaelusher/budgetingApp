import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_buddy/constants/categories.dart';
import 'package:budget_buddy/models/expense_category.dart';

const _kApiKeyPref = 'gemini_api_key';

/// What the model read off the receipt. Any field can be missing.
class ReceiptScanResult {
  final String merchant;
  final double? total;
  final DateTime? date;
  final ExpenseCategory? category;

  const ReceiptScanResult({
    this.merchant = '',
    this.total,
    this.date,
    this.category,
  });

  /// Parses the JSON object the model returns (merchant/total/date/category).
  factory ReceiptScanResult.fromJson(Map<String, dynamic> j) {
    final rawDate = j['date'] as String?;
    DateTime? date;
    if (rawDate != null) {
      date = DateTime.tryParse(rawDate);
    }
    final categoryName = j['category'] as String?;
    ExpenseCategory? category;
    if (categoryName != null) {
      for (final c in kCategories) {
        if (c.name == categoryName) category = c;
      }
    }
    return ReceiptScanResult(
      merchant: (j['merchant'] as String?)?.trim() ?? '',
      total: (j['total'] as num?)?.toDouble(),
      date: date,
      category: category,
    );
  }
}

class ReceiptScanException implements Exception {
  final String message;
  const ReceiptScanException(this.message);
  @override
  String toString() => message;
}

/// Optional receipt scanning via Google's Gemini API free tier.
///
/// Two modes:
/// - **Proxy** (store builds): compile with
///   `--dart-define=SCAN_PROXY_URL=https://...workers.dev` and receipts go to
///   your server (see proxy/receipt_scan_worker.js), which holds the Gemini
///   key. Users never see, store, or need a key.
/// - **Bring-your-own-key** (dev/personal): without a proxy URL, the user
///   pastes their own free key, stored locally. Kept separate from AppState
///   so the key never rides along in JSON backups.
class ReceiptScanner {
  /// Set at build time; empty means BYO-key mode.
  static const proxyUrl = String.fromEnvironment('SCAN_PROXY_URL');

  static bool get usesProxy => proxyUrl.isNotEmpty;

  /// Tried in order. The `-latest` alias tracks whatever flash model Google
  /// currently serves; the concrete names cover accounts where the alias is
  /// unavailable (older grandfathered keys resolve the 2.5 name instead).
  static const models = [
    'gemini-flash-latest',
    'gemini-3.5-flash',
    'gemini-2.5-flash',
  ];

  static Future<String?> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_kApiKeyPref)?.trim();
    return (key == null || key.isEmpty) ? null : key;
  }

  static Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(_kApiKeyPref);
    } else {
      await prefs.setString(_kApiKeyPref, trimmed);
    }
  }

  static Map<String, dynamic> buildRequestBody(
      Uint8List imageBytes, String mimeType) {
    return {
      'contents': [
        {
          'parts': [
            {
              'text': 'Read this receipt. Extract the merchant name, the '
                  'final total paid, the purchase date, and pick the best '
                  'matching expense category from the allowed list.',
            },
            {
              'inlineData': {
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'merchant': {'type': 'STRING'},
            'total': {'type': 'NUMBER'},
            'date': {
              'type': 'STRING',
              'description': 'Purchase date as YYYY-MM-DD, if visible',
            },
            'category': {
              'type': 'STRING',
              'enum': [for (final c in kCategories) c.name],
            },
          },
          'required': ['merchant', 'total'],
        },
      },
    };
  }

  /// Extracts the structured result out of a raw generateContent response.
  static ReceiptScanResult parseResponse(Map<String, dynamic> body) {
    final candidates = body['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const ReceiptScanException(
          'The scanner returned no result — try a clearer photo.');
    }
    final parts =
        ((candidates.first as Map)['content'] as Map?)?['parts'] as List?;
    final text = parts != null && parts.isNotEmpty
        ? (parts.first as Map)['text'] as String?
        : null;
    if (text == null) {
      throw const ReceiptScanException(
          'The scanner returned no result — try a clearer photo.');
    }
    try {
      return ReceiptScanResult.fromJson(
          jsonDecode(text) as Map<String, dynamic>);
    } on FormatException {
      throw const ReceiptScanException(
          'Could not read that receipt — try a clearer photo.');
    }
  }

  static Future<ReceiptScanResult> scan(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    try {
      if (usesProxy) {
        return await _scanViaProxy(httpClient, imageBytes, mimeType);
      }
      return await _scanDirect(httpClient, imageBytes, mimeType);
    } finally {
      if (client == null) httpClient.close();
    }
  }

  static Future<ReceiptScanResult> _scanViaProxy(
      http.Client httpClient, Uint8List imageBytes, String mimeType) async {
    final http.Response response;
    try {
      response = await httpClient
          .post(Uri.parse(proxyUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'mimeType': mimeType,
                'data': base64Encode(imageBytes),
              }))
          .timeout(const Duration(seconds: 45));
    } catch (_) {
      throw const ReceiptScanException(
          'Could not reach the scan service — check your internet connection.');
    }
    if (response.statusCode == 200) {
      return parseResponse(jsonDecode(response.body) as Map<String, dynamic>);
    }
    if (response.statusCode == 429) {
      throw const ReceiptScanException(
          'The scanner is busy — try again in a minute.');
    }
    throw ReceiptScanException(
        'Scan failed (HTTP ${response.statusCode}) — try again.');
  }

  static Future<ReceiptScanResult> _scanDirect(
      http.Client httpClient, Uint8List imageBytes, String mimeType) async {
    final apiKey = await getApiKey();
    if (apiKey == null) {
      throw const ReceiptScanException('No API key set.');
    }
    final requestBody = jsonEncode(buildRequestBody(imageBytes, mimeType));

    for (var i = 0; i < models.length; i++) {
        final uri = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/${models[i]}:generateContent?key=$apiKey');
        final http.Response response;
        try {
          response = await httpClient
              .post(uri,
                  headers: {'Content-Type': 'application/json'},
                  body: requestBody)
              .timeout(const Duration(seconds: 45));
        } catch (_) {
          throw const ReceiptScanException(
              'Could not reach Google — check your internet connection.');
        }

        if (response.statusCode == 200) {
          return parseResponse(
              jsonDecode(response.body) as Map<String, dynamic>);
        }
        if (response.statusCode == 404 && i < models.length - 1) {
          continue; // model not available on this account — try the next one
        }
        if (response.statusCode == 400 || response.statusCode == 403) {
          throw const ReceiptScanException(
              'Google rejected the API key — check it in the scan settings.');
        }
        if (response.statusCode == 429) {
          throw const ReceiptScanException(
              'Free-tier limit reached — try again in a minute.');
        }
      throw ReceiptScanException(
          'Scan failed (HTTP ${response.statusCode}) — try again.');
    }
    throw const ReceiptScanException('No Gemini model available.');
  }
}
