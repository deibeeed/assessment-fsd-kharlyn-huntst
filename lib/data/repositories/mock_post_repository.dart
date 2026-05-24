import 'package:ad_ranking_prototype/data/models/category.dart';
import 'package:ad_ranking_prototype/data/models/post.dart';
import 'package:ad_ranking_prototype/data/repositories/post_repository.dart';

class _Template {
  const _Template(this.caption, this.categories);
  final String caption;
  final List<Category> categories;
}

class _Author {
  const _Author(this.name, this.handle);
  final String name;
  final String handle;
}

class _BaseLocation {
  const _BaseLocation(this.name, this.latitude, this.longitude);
  final String name;
  final double latitude;
  final double longitude;
}

const List<_Template> _templates = [
  _Template('Sunday slow morning ☕', [Category.coffee]),
  _Template('Best lechon in town hands down 🐖', [Category.food]),
  _Template('Trail run before sunrise 🌅', [Category.fitness, Category.travel]),
  _Template('New zine drop at Folio this weekend', [Category.books]),
  _Template('Skincare haul — finally found a serum that works', [Category.beauty]),
  _Template('Pour-over hits different at home', [Category.coffee]),
  _Template('Found this denim jacket at a thrift store', [Category.fashion]),
  _Template('Hidden ramen spot in Poblacion 🍜', [Category.food]),
  _Template('Setting up my new mechanical keyboard', [Category.tech]),
  _Template('Beach day in Bantayan 🏝️', [Category.travel]),
  _Template('Match green tea + adobo combo, don\'t judge', [Category.food, Category.coffee]),
  _Template('Finished my first 10k 🏃', [Category.fitness]),
  _Template('Book club pick this month: Pachinko', [Category.books]),
  _Template('Lipstick that actually lasts through halo-halo', [Category.beauty, Category.food]),
  _Template('Reviewing the new mid-range phone', [Category.tech]),
  _Template('Saturday market finds — fresh strawberries', [Category.food]),
  _Template('Pilates studio downtown, recommend', [Category.fitness]),
  _Template('OOTD: linen pants + canvas sneakers', [Category.fashion]),
  _Template('Cafe-hopping in Quezon City this weekend', [Category.coffee, Category.travel]),
  _Template('Best taho in Baguio fight me', [Category.food, Category.travel]),
  _Template('Annotated bookstack 📚', [Category.books]),
  _Template('Gym progress, month 6', [Category.fitness]),
  _Template('Tablet for digital art, finally upgraded', [Category.tech]),
  _Template('Skincare routine simplified to 3 steps', [Category.beauty]),
  _Template('Coffee tasting flight at the roastery', [Category.coffee]),
];

const List<_Author> _authors = [
  _Author('Maria Santos', '@maria.eats'),
  _Author('Carlos Reyes', '@carl.runs'),
  _Author('Aileen Cruz', '@aileen.style'),
  _Author('Noel Mendoza', '@noel.brews'),
  _Author('Trisha Lim', '@trisha.reads'),
  _Author('Migs Aquino', '@migs.builds'),
  _Author('Patty Yu', '@patty.glows'),
  _Author('Jaime de la Rosa', '@jaime.travels'),
  _Author('Rina Bautista', '@rina.lifts'),
  _Author('Vince Pascual', '@vince.codes'),
  _Author('Bea Tan', '@bea.brunches'),
  _Author('Joey Soriano', '@joey.serves'),
  _Author('Mika Velasco', '@mika.frames'),
  _Author('Kuya Andoy', '@andoy.tales'),
  _Author('Ina Mercado', '@ina.curates'),
];

const List<_BaseLocation> _baseLocations = [
  _BaseLocation('Manila', 14.5995, 120.9842),
  _BaseLocation('Cebu', 10.3157, 123.8854),
  _BaseLocation('Davao', 7.1907, 125.4553),
  _BaseLocation('Baguio', 16.4023, 120.5960),
];

class MockPostRepository implements PostRepository {
  static const int _count = 100;

  @override
  Future<List<Post>> getAll() async {
    final now = DateTime.now();
    return List.generate(_count, (n) {
      final template = _templates[n % _templates.length];
      final author = _authors[n % _authors.length];
      final base = _baseLocations[n % _baseLocations.length];
      final jitter = (n % 10) * 0.001;
      return Post(
        id: 'post-$n',
        authorName: author.name,
        authorHandle: author.handle,
        caption: template.caption,
        imageUrl: 'https://picsum.photos/seed/post-$n/600/600',
        categories: template.categories,
        latitude: base.latitude + jitter,
        longitude: base.longitude - jitter,
        timestamp: now.subtract(Duration(hours: n)),
      );
    });
  }
}
