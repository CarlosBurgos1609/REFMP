import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Solicita permisos y obtiene la ubicación actual del usuario
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio de ubicación está activado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null; // Servicio de ubicación desactivado
    }

    // Verificar permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null; // Permiso denegado
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null; // Permiso denegado permanentemente
    }

    // Obtener la ubicación actual
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
