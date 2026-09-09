import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// Why asking for a location did not produce one, in terms the app can act on.
///
/// A single "it failed" would leave the screen offering "Try again" to someone
/// who has permanently denied the permission, where the only way forward is
/// Settings.
enum LocationOutcome {
  ok,

  /// The phone's location switch is off. Nothing app-level can fix it.
  serviceOff,

  /// Refused this once. Asking again is reasonable.
  denied,

  /// Refused for good. Only the system settings page can undo it.
  deniedForever,

  /// Permission granted, but no fix came back - indoors, or a cold start.
  unavailable,
}

class LocationResult {
  const LocationResult(this.outcome, {this.address = '', this.lat, this.lng});

  final LocationOutcome outcome;
  final String address;

  /// The fix itself.
  ///
  /// The words are for the person reading them; these are what a rider
  /// navigates to. Keeping only the words - which is what this used to do -
  /// threw away the accurate half of a location the buyer had just granted
  /// permission for.
  final double? lat;
  final double? lng;

  bool get isOk => outcome == LocationOutcome.ok && address.isNotEmpty;

  String get message {
    switch (outcome) {
      case LocationOutcome.ok:
        return address;
      case LocationOutcome.serviceOff:
        return 'Location is switched off on this phone. Turn it on and try again.';
      case LocationOutcome.denied:
        return 'AgriFair needs location permission to fill in your address.';
      case LocationOutcome.deniedForever:
        return 'Location is blocked for AgriFair. Allow it in Settings to use this.';
      case LocationOutcome.unavailable:
        return 'Could not get a fix. Try again outdoors, or type the address instead.';
    }
  }
}

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Asks for permission if needed, then turns a fix into a readable address.
  ///
  /// Nothing here runs unprompted: a rice app that reaches for someone's
  /// coordinates on launch has not earned that, so this is called only when a
  /// person taps the address themselves.
  Future<LocationResult> currentAddress() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(LocationOutcome.serviceOff);
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(LocationOutcome.deniedForever);
    }

    if (permission == LocationPermission.denied) {
      return const LocationResult(LocationOutcome.denied);
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          // A delivery address does not need metre accuracy, and asking for
          // less keeps the wait short and the battery cost low.
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      return const LocationResult(LocationOutcome.unavailable);
    }

    try {
      // geocoding 5 moved from top-level functions to an instance API.
      final places = await geo.Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final address = _describe(places.isEmpty ? null : places.first);
      if (address.isEmpty) {
        return const LocationResult(LocationOutcome.unavailable);
      }

      return LocationResult(
        LocationOutcome.ok,
        address: address,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (_) {
      // Reverse geocoding needs the network. A fix without a name is not much
      // use as a delivery address, so this reports the same as no fix.
      return const LocationResult(LocationOutcome.unavailable);
    }
  }

  /// Opens the system settings page, for the case only the person can fix.
  Future<void> openSettings() => Geolocator.openAppSettings();

  /// Barangay, town, province - what a courier here would actually use, and
  /// no more precise than that.
  String _describe(geo.Placemark? place) {
    if (place == null) return '';

    final parts = <String>[
      place.subLocality ?? '',
      place.locality ?? '',
      place.administrativeArea ?? '',
    ].where((part) => part.trim().isNotEmpty).toList();

    // Duplicates are common - a city can come back as both locality and
    // administrative area - and "Manila, Manila" reads like a bug.
    final seen = <String>{};
    return parts.where((part) => seen.add(part.toLowerCase())).join(', ');
  }
}
