import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:hive/hive.dart';

class HiveEventRepository implements EventRepository {
  HiveEventRepository(this._box);

  static const String boxName = 'ad_events';

  final Box<AdEvent> _box;

  @override
  Future<void> recordImpression(String adId) async {
    await _box.add(
      AdEvent(
        adId: adId,
        type: EventType.impression,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> recordClick(String adId) async {
    await _box.add(
      AdEvent(
        adId: adId,
        type: EventType.click,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> recordPostImpression(String postId) async {
    await _box.add(
      AdEvent(
        adId: 'post:$postId',
        type: EventType.impression,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<AdEvent>> getEventsSince(DateTime since) async {
    return _box.values.where((e) => e.timestamp.isAfter(since)).toList();
  }
}
