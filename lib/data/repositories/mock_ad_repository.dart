import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';

class MockAdRepository implements AdRepository {
  @override
  Future<List<Ad>> getAll() async {
    return const [
      // Manila (14.5995, 120.9842)
      Ad(
        id: 'jollibee-manila',
        title: 'Chickenjoy Bucket — 20% off today',
        description: 'Limited-time bucket deal at Jollibee Manila stores.',
        advertiserName: 'Jollibee',
        tier: AdTier.gold,
        latitude: 14.5995,
        longitude: 120.9842,
      ),
      Ad(
        id: 'globe-manila',
        title: 'Globe Fiber 100Mbps for ₱1499',
        description: 'Upgrade your home fiber plan this month.',
        advertiserName: 'Globe Telecom',
        tier: AdTier.gold,
        latitude: 14.5547,
        longitude: 121.0244,
      ),
      Ad(
        id: 'grab-manila',
        title: '₱50 off your next GrabFood order',
        description: 'Use code SAVE50 at checkout.',
        advertiserName: 'Grab',
        tier: AdTier.silver,
        latitude: 14.6091,
        longitude: 121.0223,
      ),
      Ad(
        id: 'localcafe-manila',
        title: 'Buy 1 Get 1 espresso this week',
        description: 'Drop by Café Carpio in Quezon City.',
        advertiserName: 'Café Carpio',
        tier: AdTier.bronze,
        latitude: 14.6760,
        longitude: 121.0437,
      ),

      // Cebu (10.3157, 123.8854)
      Ad(
        id: 'ayala-cebu',
        title: 'Ayala Center Cebu mid-year sale',
        description: 'Up to 70% off on selected stores.',
        advertiserName: 'Ayala Malls',
        tier: AdTier.gold,
        latitude: 10.3181,
        longitude: 123.9054,
      ),
      Ad(
        id: 'lechon-cebu',
        title: 'Original Cebu Lechon — free delivery',
        description: '1kg orders and above ship free within Cebu City.',
        advertiserName: 'CnT Lechon',
        tier: AdTier.silver,
        latitude: 10.3270,
        longitude: 123.9038,
      ),
      Ad(
        id: 'bookshop-cebu',
        title: 'Indie bookshop pop-up this Saturday',
        description: 'New titles, secondhand finds, free coffee.',
        advertiserName: 'Folio Books',
        tier: AdTier.bronze,
        latitude: 10.3000,
        longitude: 123.9000,
      ),

      // Davao (7.1907, 125.4553)
      Ad(
        id: 'durian-davao',
        title: 'Durian harvest fest — 15% off whole fruit',
        description: 'Fresh from Davao orchards.',
        advertiserName: 'Davao Durian Co.',
        tier: AdTier.silver,
        latitude: 7.0707,
        longitude: 125.6111,
      ),
      Ad(
        id: 'eagle-davao',
        title: 'Philippine Eagle Center tour discount',
        description: 'Weekend family pass at 20% off.',
        advertiserName: 'PEC',
        tier: AdTier.bronze,
        latitude: 7.1907,
        longitude: 125.4553,
      ),

      // Baguio (16.4023, 120.5960)
      Ad(
        id: 'strawberry-baguio',
        title: 'Strawberry taho special — Mines View',
        description: 'Locally grown, top vendor in town.',
        advertiserName: 'La Trinidad Farms',
        tier: AdTier.silver,
        latitude: 16.4140,
        longitude: 120.6228,
      ),
    ];
  }
}
