import 'package:ad_ranking_prototype/data/models/ad.dart';
import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/repositories/ad_repository.dart';

class MockAdRepository implements AdRepository {
  @override
  Future<List<Ad>> getAll() async {
    return const [
      Ad(
        id: 'jollibee-manila',
        title: 'Chickenjoy Bucket — 20% off today',
        description: 'Limited-time bucket deal at Jollibee Manila stores.',
        advertiserName: 'Jollibee',
        tier: AdTier.gold,
        latitude: 14.5995,
        longitude: 120.9842,
        imageUrl:
            'https://images.unsplash.com/photo-1562967914-608f82629710?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'globe-manila',
        title: 'Globe Fiber 100Mbps for ₱1499',
        description: 'Upgrade your home fiber plan this month.',
        advertiserName: 'Globe Telecom',
        tier: AdTier.gold,
        latitude: 14.5547,
        longitude: 121.0244,
        imageUrl:
            'https://images.unsplash.com/photo-1551808525-51a94da548ce?w=600&h=600&fit=crop',
        categories: [Category.tech],
      ),
      Ad(
        id: 'grab-manila',
        title: '₱50 off your next GrabFood order',
        description: 'Use code SAVE50 at checkout.',
        advertiserName: 'Grab',
        tier: AdTier.silver,
        latitude: 14.6091,
        longitude: 121.0223,
        imageUrl:
            'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&h=600&fit=crop',
        categories: [Category.food, Category.travel],
      ),
      Ad(
        id: 'localcafe-manila',
        title: 'Buy 1 Get 1 espresso this week',
        description: 'Drop by Café Carpio in Quezon City.',
        advertiserName: 'Café Carpio',
        tier: AdTier.bronze,
        latitude: 14.6760,
        longitude: 121.0437,
        imageUrl:
            'https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=600&h=600&fit=crop',
        categories: [Category.coffee],
      ),
      Ad(
        id: 'ayala-cebu',
        title: 'Ayala Center Cebu mid-year sale',
        description: 'Up to 70% off on selected stores.',
        advertiserName: 'Ayala Malls',
        tier: AdTier.gold,
        latitude: 10.3181,
        longitude: 123.9054,
        imageUrl:
            'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=600&h=600&fit=crop',
        categories: [Category.fashion, Category.beauty],
      ),
      Ad(
        id: 'lechon-cebu',
        title: 'Original Cebu Lechon — free delivery',
        description: '1kg orders and above ship free within Cebu City.',
        advertiserName: 'CnT Lechon',
        tier: AdTier.silver,
        latitude: 10.3270,
        longitude: 123.9038,
        imageUrl:
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'bookshop-cebu',
        title: 'Indie bookshop pop-up this Saturday',
        description: 'New titles, secondhand finds, free coffee.',
        advertiserName: 'Folio Books',
        tier: AdTier.bronze,
        latitude: 10.3000,
        longitude: 123.9000,
        imageUrl:
            'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=600&h=600&fit=crop',
        categories: [Category.books, Category.coffee],
      ),
      Ad(
        id: 'durian-davao',
        title: 'Durian harvest fest — 15% off whole fruit',
        description: 'Fresh from Davao orchards.',
        advertiserName: 'Davao Durian Co.',
        tier: AdTier.silver,
        latitude: 7.0707,
        longitude: 125.6111,
        imageUrl:
            'https://images.unsplash.com/photo-1601004890684-d8cbf643f5f2?w=600&h=600&fit=crop',
        categories: [Category.food],
      ),
      Ad(
        id: 'eagle-davao',
        title: 'Philippine Eagle Center tour discount',
        description: 'Weekend family pass at 20% off.',
        advertiserName: 'PEC',
        tier: AdTier.bronze,
        latitude: 7.1907,
        longitude: 125.4553,
        imageUrl:
            'https://images.unsplash.com/photo-1518709268805-4e9042af2176?w=600&h=600&fit=crop',
        categories: [Category.travel],
      ),
      Ad(
        id: 'strawberry-baguio',
        title: 'Strawberry taho special — Mines View',
        description: 'Locally grown, top vendor in town.',
        advertiserName: 'La Trinidad Farms',
        tier: AdTier.silver,
        latitude: 16.4140,
        longitude: 120.6228,
        imageUrl:
            'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=600&h=600&fit=crop',
        categories: [Category.food, Category.travel],
      ),
    ];
  }
}
