import 'package:ad_ranking_prototype/data/models/post_like.dart';
import 'package:hive/hive.dart';

class PostLikeAdapter extends TypeAdapter<PostLike> {
  @override
  final int typeId = 2;

  @override
  PostLike read(BinaryReader reader) {
    final postId = reader.readString();
    final ts = reader.readInt();
    return PostLike(
      postId: postId,
      likedAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  void write(BinaryWriter writer, PostLike obj) {
    writer.writeString(obj.postId);
    writer.writeInt(obj.likedAt.millisecondsSinceEpoch);
  }
}
