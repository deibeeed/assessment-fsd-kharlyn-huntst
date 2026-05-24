import 'package:ad_ranking_prototype/data/models/user_location.dart';
import 'package:ad_ranking_prototype/presentation/location/cubit/location_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LocationPicker extends StatelessWidget {
  const LocationPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<LocationCubit>();
    return DropdownButton<UserLocation>(
      value: cubit.state,
      icon: const Icon(Icons.location_on_outlined),
      underline: const SizedBox.shrink(),
      onChanged: (loc) {
        if (loc != null) cubit.select(loc);
      },
      items: [
        for (final loc in cubit.available)
          DropdownMenuItem(value: loc, child: Text(loc.name)),
      ],
    );
  }
}
