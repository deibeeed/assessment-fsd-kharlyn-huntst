import 'package:ad_ranking_prototype/data/models/ad_event.dart';

abstract class EventRepository {
  Future<void> recordImpression(String adId);
  Future<void> recordClick(String adId);
  Future<List<AdEvent>> getEventsSince(DateTime since);
}
