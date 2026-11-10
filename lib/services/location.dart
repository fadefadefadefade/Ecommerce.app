import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the phone is, for the courier's On Duty, Depart and Arrived (checked against the hub's 500 m area).
class PhoneLocation {
  final double? lat;
  final double? lng;

  /// Why there is no location (permission denied, location off), with [settings] when the phone's Settings can fix it.
  final String? problem;
  final bool settings;

  const PhoneLocation._(this.lat, this.lng, this.problem, this.settings);

  bool get ok => lat != null && lng != null;

  Map<String, dynamic> get body => ok ? {'lat': lat, 'lng': lng} : {};

  /// Asks for permission the first time it is needed; never throws.
  static Future<PhoneLocation> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const PhoneLocation._(null, null, 'Location is turned off. Turn on Location in your phone\'s quick settings, then try again.', true);
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return const PhoneLocation._(null, null,
            'ALVY needs your location to check you are at the hub. Allow location for ALVY ("While using the app") in Settings › Apps › ALVY › Permissions.', true);
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)));
      return PhoneLocation._(pos.latitude, pos.longitude, null, false);
    } catch (e) {
      return PhoneLocation._(null, null, 'Could not get your location ($e). Go outside or near a window and try again.', false);
    }
  }

  static Future<void> openSettings() => Geolocator.openAppSettings();

  /// Opens the map app (Google Maps or Waze, the phone asks) with directions to a place.
  static Future<bool> navigate({double? lat, double? lng, String? address}) {
    final dest = lat != null && lng != null ? '$lat,$lng' : Uri.encodeComponent(address ?? '');
    return launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest'), mode: LaunchMode.externalApplication);
  }
}
