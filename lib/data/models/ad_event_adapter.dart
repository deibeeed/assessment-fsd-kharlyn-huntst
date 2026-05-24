import 'package:ad_ranking_prototype/data/models/ad_event.dart';
import 'package:hive/hive.dart';

class AdEventAdapter extends TypeAdapter<AdEvent> {
  @override
  final int typeId = 1;

  @override
  AdEvent read(BinaryReader reader) {
    final adId = reader.readString();
    final typeIndex = reader.readByte();
    final ts = reader.readInt();
    return AdEvent(
      adId: adId,
      type: EventType.values[typeIndex],
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  void write(BinaryWriter writer, AdEvent obj) {
    writer.writeString(obj.adId);
    writer.writeByte(obj.type.index);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
  }
}
