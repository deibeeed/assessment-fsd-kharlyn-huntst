import 'package:equatable/equatable.dart';

sealed class AnalyticsEvent extends Equatable {
  const AnalyticsEvent();
  @override
  List<Object?> get props => const [];
}

class ImpressionRecorded extends AnalyticsEvent {
  const ImpressionRecorded(this.adId);
  final String adId;
  @override
  List<Object?> get props => [adId];
}

class ClickRecorded extends AnalyticsEvent {
  const ClickRecorded(this.adId);
  final String adId;
  @override
  List<Object?> get props => [adId];
}
