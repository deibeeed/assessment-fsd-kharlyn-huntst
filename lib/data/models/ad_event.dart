import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

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
