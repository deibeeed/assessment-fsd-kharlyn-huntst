import 'package:ad_ranking_prototype/core/distance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('haversineKm', () {
    test('returns 0 for identical coordinates', () {
      expect(haversineKm(14.5995, 120.9842, 14.5995, 120.9842), 0);
    });

    test('returns ~570 km for Manila to Cebu', () {
      // Manila: 14.5995, 120.9842; Cebu: 10.3157, 123.8854
      final d = haversineKm(14.5995, 120.9842, 10.3157, 123.8854);
      expect(d, closeTo(570, 20));
    });
  });
}
