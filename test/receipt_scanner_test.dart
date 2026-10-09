import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:budget_buddy/services/receipt_scanner.dart';

Map<String, dynamic> geminiResponse(Map<String, dynamic> payload) => {
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(payload)},
            ],
          },
        },
      ],
    };

void main() {
  test('parses a full receipt payload', () {
    final result = ReceiptScanner.parseResponse(geminiResponse({
      'merchant': 'Trader Joe\'s',
      'total': 54.23,
      'date': '2026-08-05',
      'category': 'Food & Dining',
    }));
    expect(result.merchant, 'Trader Joe\'s');
    expect(result.total, 54.23);
    expect(result.date, DateTime(2026, 8, 5));
    expect(result.category?.name, 'Food & Dining');
  });

  test('tolerates missing date and unknown category', () {
    final result = ReceiptScanner.parseResponse(geminiResponse({
      'merchant': 'Shell',
      'total': 40,
      'category': 'Not A Real Category',
    }));
    expect(result.merchant, 'Shell');
    expect(result.total, 40);
    expect(result.date, isNull);
    expect(result.category, isNull);
  });

  test('empty candidates raise a friendly error', () {
    expect(
      () => ReceiptScanner.parseResponse({'candidates': []}),
      throwsA(isA<ReceiptScanException>()),
    );
  });

  test('non-JSON model text raises a friendly error', () {
    expect(
      () => ReceiptScanner.parseResponse({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'sorry, cannot read this'},
              ],
            },
          },
        ],
      }),
      throwsA(isA<ReceiptScanException>()),
    );
  });

  test('request body carries the image and the category enum', () {
    final body =
        ReceiptScanner.buildRequestBody(Uint8List.fromList([1, 2, 3]), 'image/png');
    final parts =
        ((body['contents'] as List).first as Map)['parts'] as List;
    final inline = (parts[1] as Map)['inlineData'] as Map;
    expect(inline['mimeType'], 'image/png');
    expect(inline['data'], base64Encode([1, 2, 3]));

    final schema = ((body['generationConfig'] as Map)['responseSchema']) as Map;
    final enumValues =
        ((schema['properties'] as Map)['category'] as Map)['enum'] as List;
    expect(enumValues, contains('Food & Dining'));
    expect(enumValues, contains('Transport'));
  });
}
