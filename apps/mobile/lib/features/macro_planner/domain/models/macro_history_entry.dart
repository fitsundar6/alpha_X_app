import 'macro_input.dart';
import 'macro_result.dart';

/// Historical record of a saved macro calculation
class MacroHistoryEntry {
  final String id;
  final DateTime timestamp;
  final MacroInput input;
  final MacroResult result;
  final String note;

  const MacroHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.input,
    required this.result,
    this.note = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'input': input.toJson(),
      'result': result.toJson(),
      'note': note,
    };
  }

  factory MacroHistoryEntry.fromJson(Map<String, dynamic> json) {
    return MacroHistoryEntry(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      input: MacroInput.fromJson(json['input'] as Map<String, dynamic>),
      result: MacroResult.fromJson(json['result'] as Map<String, dynamic>),
      note: json['note'] as String? ?? '',
    );
  }
}
