import 'package:equatable/equatable.dart';

enum EventType { impression, click }

class AdEvent extends Equatable {
  const AdEvent({
    required this.adId,
    required this.type,
    required this.timestamp,
  });

  final String adId;
  final EventType type;
  final DateTime timestamp;

  @override
  List<Object?> get props => [adId, type, timestamp];
}
