import 'package:ad_ranking_prototype/data/models/ad.dart';

abstract class AdRepository {
  Future<List<Ad>> getAll();
}
