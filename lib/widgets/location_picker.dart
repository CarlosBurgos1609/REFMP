import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Clase para almacenar resultados de búsqueda con dirección
class SearchResult {
  final double latitude;
  final double longitude;
  final String address;
  final String name;

  SearchResult({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.name,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({Key? key, this.initialLocation})
      : super(key: key);

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _selectedLocation;
  String _address = '';
  String _placeName = ''; // Nombre del lugar para Google Maps
  bool _isLoading = false;
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation == null) {
      _getCurrentLocation();
    } else {
      _getAddressFromLatLng(_selectedLocation!);
    }
  }

  // Método para buscar ubicación por texto
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      List<Location> locations = await locationFromAddress(query);
      List<SearchResult> results = [];

      for (var location in locations) {
        // Obtener la dirección legible de cada resultado
        String address = '';
        String name = query;

        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];

            // Construir el nombre del lugar
            name = place.name ?? place.street ?? query;

            // Construir la dirección completa
            List<String> addressParts = [];
            if (place.street != null && place.street!.isNotEmpty) {
              addressParts.add(place.street!);
            }
            if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              addressParts.add(place.subLocality!);
            }
            if (place.locality != null && place.locality!.isNotEmpty) {
              addressParts.add(place.locality!);
            }
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty) {
              addressParts.add(place.administrativeArea!);
            }
            if (place.country != null && place.country!.isNotEmpty) {
              addressParts.add(place.country!);
            }

            address = addressParts.join(', ');
          }
        } catch (e) {
          address = 'Ubicación encontrada';
        }

        results.add(SearchResult(
          latitude: location.latitude,
          longitude: location.longitude,
          address: address,
          name: name,
        ));
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      _showError('No se encontraron resultados para "$query"');
    }
  }

  // Seleccionar un resultado de búsqueda
  void _selectSearchResult(SearchResult result) {
    final newLocation = LatLng(result.latitude, result.longitude);
    setState(() {
      _selectedLocation = newLocation;
      _address = result.address;
      _placeName = result.name; // Guardar el nombre del lugar
      _searchResults = [];
      _searchController.clear();
    });
    _mapController.move(newLocation, 16);
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Los servicios de ubicación están desactivados');
        setState(() => _isLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('Permiso de ubicación denegado');
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Permisos de ubicación permanentemente denegados');
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _mapController.move(_selectedLocation!, 15);
      _getAddressFromLatLng(_selectedLocation!);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al obtener ubicación: $e');
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Obtener el nombre del lugar
        String name = '';
        if (place.name != null && place.name!.isNotEmpty) {
          name = place.name!;
        } else if (place.street != null && place.street!.isNotEmpty) {
          name = place.street!;
        }

        List<String> addressParts = [];
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        setState(() {
          _address = addressParts.join(', ');
          _placeName = name.isNotEmpty
              ? name
              : addressParts.isNotEmpty
                  ? addressParts.first
                  : 'Ubicación seleccionada';
        });
      }
    } catch (e) {
      setState(() {
        _address = 'Ubicación seleccionada';
        _placeName = 'Ubicación seleccionada';
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedLocation = position;
      _searchResults = [];
    });
    _getAddressFromLatLng(position);
  }

  // Abrir Google Maps en WebView para obtener el link de compartir
  Future<void> _openGoogleMapsWebView() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GoogleMapsWebViewScreen(
          initialQuery:
              _placeName.isNotEmpty ? '$_placeName, $_address' : _address,
          initialLat: _selectedLocation?.latitude,
          initialLng: _selectedLocation?.longitude,
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      // El usuario obtuvo un link de Google Maps
      Navigator.pop(context, {
        'url': result,
        'lat': _selectedLocation?.latitude ?? 0,
        'lng': _selectedLocation?.longitude ?? 0,
        'address': _address,
        'placeName': _placeName,
      });
    }
  }

  void _confirmLocation() {
    if (_selectedLocation == null) {
      _showError('Por favor selecciona una ubicación en el mapa');
      return;
    }

    // Abrir Google Maps para obtener el link real
    _openGoogleMapsWebView();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Ubicación'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Mi ubicación',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Mapa
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _selectedLocation ?? const LatLng(4.570868, -74.297333),
              initialZoom: 12,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.refmp',
              ),
              if (_selectedLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 50,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Barra de búsqueda
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar dirección o lugar...',
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: _searchLocation,
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Botón de buscar
                if (_searchController.text.isNotEmpty &&
                    _searchResults.isEmpty &&
                    !_isSearching)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _searchLocation(_searchController.text),
                        icon: const Icon(Icons.search),
                        label: const Text('Buscar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Indicador de carga en búsqueda
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Buscando...'),
                      ],
                    ),
                  ),

                // Resultados de búsqueda con nombre y dirección
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            result.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            result.address,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Panel inferior con información
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedLocation != null) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              const Icon(Icons.location_on, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_placeName.isNotEmpty)
                                Text(
                                  _placeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Text(
                                _address.isNotEmpty
                                    ? _address
                                    : 'Cargando dirección...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else
                    const Text(
                      'Busca o toca en el mapa para seleccionar ubicación',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          _selectedLocation != null ? _confirmLocation : null,
                      icon: const Icon(Icons.check),
                      label: const Text('Confirmar Ubicación'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// =============================================================================
// PANTALLA DE GOOGLE MAPS WEBVIEW PARA OBTENER LINK DE COMPARTIR
// =============================================================================

class GoogleMapsWebViewScreen extends StatefulWidget {
  final String? initialQuery;
  final double? initialLat;
  final double? initialLng;

  const GoogleMapsWebViewScreen({
    Key? key,
    this.initialQuery,
    this.initialLat,
    this.initialLng,
  }) : super(key: key);

  @override
  State<GoogleMapsWebViewScreen> createState() =>
      _GoogleMapsWebViewScreenState();
}

class _GoogleMapsWebViewScreenState extends State<GoogleMapsWebViewScreen> {
  late WebViewController _controller;
  final TextEditingController _linkController = TextEditingController();
  bool _isLoading = true;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    String url;
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      final encodedQuery = Uri.encodeComponent(widget.initialQuery!);
      url = 'https://www.google.com/maps/search/$encodedQuery';
    } else if (widget.initialLat != null && widget.initialLng != null) {
      url =
          'https://www.google.com/maps/@${widget.initialLat},${widget.initialLng},15z';
    } else {
      url = 'https://www.google.com/maps';
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 10; SM-G975F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _currentUrl = url;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _currentUrl = url;
              });
              // Auto-detectar si es un link de lugar
              _checkForShareableLink(url);
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;

            // Bloquear esquemas no soportados (intent://, market://, etc.)
            if (url.startsWith('intent://') ||
                url.startsWith('market://') ||
                url.startsWith('geo://') ||
                url.startsWith('tel://') ||
                url.startsWith('mailto://')) {
              // Intentar abrir en app externa
              _launchExternalUrl(url);
              return NavigationDecision.prevent;
            }

            // Permitir navegación normal para HTTP/HTTPS
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }

            // Bloquear otros esquemas desconocidos
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  Future<void> _launchExternalUrl(String url) async {
    try {
      // Convertir intent:// a https:// para Google Maps
      if (url.contains('maps.google.com') || url.contains('google.com/maps')) {
        // Extraer la URL de fallback si existe
        final fallbackMatch =
            RegExp(r'S\.browser_fallback_url=([^;]+)').firstMatch(url);
        if (fallbackMatch != null) {
          final fallbackUrl = Uri.decodeComponent(fallbackMatch.group(1)!);
          await launchUrl(Uri.parse(fallbackUrl),
              mode: LaunchMode.externalApplication);
          return;
        }
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  void _checkForShareableLink(String url) {
    // Si la URL contiene /place/ es un lugar específico
    if (url.contains('/place/') || url.contains('maps.app.goo.gl')) {
      setState(() {
        _linkController.text = url;
      });
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _linkController.text = data.text!;
      });
    }
  }

  void _confirmLink() {
    final link = _linkController.text.trim();
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor pega el link de Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que sea un link de Google Maps
    if (!link.contains('google.com/maps') &&
        !link.contains('maps.app.goo.gl') &&
        !link.contains('goo.gl/maps')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un link válido de Google Maps'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Retornar como Map para que el código que llama pueda acceder a result['url']
    Navigator.pop(context, {'url': link});
  }

  void _useCurrentUrl() {
    if (_currentUrl.contains('/place/')) {
      _linkController.text = _currentUrl;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Navega a un lugar específico primero'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Maps'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Instrucciones
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Instrucciones:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1. Busca el lugar del evento\n'
                  '2. Toca en el lugar para ver su información\n'
                  '3. Toca "Compartir" y copia el link\n'
                  '4. Pega el link abajo',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),

          // WebView de Google Maps
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.blue),
                  ),
              ],
            ),
          ),

          // Panel inferior para pegar el link
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo para pegar el link
                TextField(
                  controller: _linkController,
                  decoration: InputDecoration(
                    hintText: 'Pega aquí el link de Google Maps...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(Icons.link, color: Colors.blue),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.paste, color: Colors.blue),
                          onPressed: _pasteFromClipboard,
                          tooltip: 'Pegar',
                        ),
                        if (_currentUrl.contains('/place/'))
                          IconButton(
                            icon:
                                const Icon(Icons.download, color: Colors.green),
                            onPressed: _useCurrentUrl,
                            tooltip: 'Usar URL actual',
                          ),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón confirmar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmLink,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar Link'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }
}
