import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:ad_ranking_prototype/data/repositories/event_repository.dart';
import 'package:hive/hive.dart';

class HiveEventRepository implements EventRepository {
  HiveEventRepository({
    required Box<AdEvent> adEventBox,
    required Box<AdEvent> postEventBox,
  })  : _adEventBox = adEventBox,
        _postEventBox = postEventBox;

  static const String adEventBoxName = 'ad_events';
  static const String postEventBoxName = 'post_events';

  // Backwards-compat alias for any caller still using the old name.
  static const String boxName = adEventBoxName;

  final Box<AdEvent> _adEventBox;
  final Box<AdEvent> _postEventBox;

  @override
  Future<void> recordImpression(String adId) async {
    await _adEventBox.add(
      AdEvent(
        adId: adId,
        type: EventType.impression,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> recordClick(String adId) async {
    await _adEventBox.add(
      AdEvent(
        adId: adId,
        type: EventType.click,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> recordPostImpression(String postId) async {
    await _postEventBox.add(
      AdEvent(
        adId: postId,
        type: EventType.impression,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<AdEvent>> getEventsSince(DateTime since) async {
    return _adEventBox.values.where((e) => e.timestamp.isAfter(since)).toList();
  }
}
