import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/data/repositories/location_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationCubit extends Cubit<UserLocation> {
  LocationCubit(this._repository) : super(_repository.defaultLocation);

  final LocationRepository _repository;

  List<UserLocation> get available => _repository.getAll();

  void select(UserLocation location) => emit(location);
}
