/// Maximum distance in km at which proximity score is non-zero.
const double kMaxProximityKm = 50.0;

/// Window for counting recent impressions when computing decay.
const Duration kImpressionDecayWindow = Duration(minutes: 10);

/// If an ad has not been shown in this window, it gets a starvation boost.
const Duration kStarvationWindow = Duration(minutes: 5);

/// How many ads to show in the feed.
const int kFeedSize = 10;
