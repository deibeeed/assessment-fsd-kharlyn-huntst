import 'package:ad_ranking_prototype/data/models/user_location.dart';

class LocationRepository {
  const LocationRepository();

  static const List<UserLocation> _locations = [
    UserLocation(name: 'Manila', latitude: 14.5995, longitude: 120.9842),
    UserLocation(name: 'Cebu', latitude: 10.3157, longitude: 123.8854),
    UserLocation(name: 'Davao', latitude: 7.1907, longitude: 125.4553),
    UserLocation(name: 'Baguio', latitude: 16.4023, longitude: 120.5960),
  ];

  List<UserLocation> getAll() => _locations;

  UserLocation get defaultLocation => _locations.first;
}
