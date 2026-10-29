import 'segment.dart';

/// Configuração do negócio, criada no onboarding.
///
/// Existe apenas uma linha (id = 1) na tabela `business_config`.
class BusinessConfig {
  const BusinessConfig({
    required this.businessName,
    required this.segment,
    this.currency = 'BRL',
    required this.tracksBatch,
    required this.tracksExpiry,
    required this.multiLocation,
    this.createdAt,
  });

  final String businessName;
  final Segment segment;
  final String currency;
  final bool tracksBatch;
  final bool tracksExpiry;
  final bool multiLocation;
  final DateTime? createdAt;

  bool get isConfigured => businessName.trim().isNotEmpty;

  BusinessConfig copyWith({
    String? businessName,
    Segment? segment,
    String? currency,
    bool? tracksBatch,
    bool? tracksExpiry,
    bool? multiLocation,
    DateTime? createdAt,
  }) {
    return BusinessConfig(
      businessName: businessName ?? this.businessName,
      segment: segment ?? this.segment,
      currency: currency ?? this.currency,
      tracksBatch: tracksBatch ?? this.tracksBatch,
      tracksExpiry: tracksExpiry ?? this.tracksExpiry,
      multiLocation: multiLocation ?? this.multiLocation,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory BusinessConfig.fromMap(Map<String, Object?> map) {
    return BusinessConfig(
      businessName: (map['business_name'] as String?) ?? '',
      segment: Segment.fromName((map['segment'] as String?) ?? 'mercado'),
      currency: (map['currency'] as String?) ?? 'BRL',
      tracksBatch: _toBool(map['tracks_batch']),
      tracksExpiry: _toBool(map['tracks_expiry']),
      multiLocation: _toBool(map['multi_location']),
      createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': 1,
      'business_name': businessName.trim(),
      'segment': segment.name,
      'currency': currency,
      'tracks_batch': tracksBatch ? 1 : 0,
      'tracks_expiry': tracksExpiry ? 1 : 0,
      'multi_location': multiLocation ? 1 : 0,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
    };
  }

  static bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return false;
  }
}
