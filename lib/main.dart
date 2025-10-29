import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qibla Direction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const QiblaCompass(),
    );
  }
}

class QiblaCompass extends StatefulWidget {
  const QiblaCompass({super.key});

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double _currentHeading = 0.0;
  double _qiblaDirection = 0.0;
  StreamSubscription? _magnetometerSubscription;

  // For calculating heading from magnetometer
  double _magnetometerX = 0.0;
  double _magnetometerY = 0.0;

  // Location data
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationError = '';

  // Mecca coordinates (Ka'aba)
  static const double meccaLat = 21.4225;
  static const double meccaLon = 39.8262;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Initialize both location and compass
  Future<void> _initializeApp() async {
    await _requestLocationPermission();
    await _getCurrentLocation();
    _initCompass();
  }

  // Step 1: Request location permission
  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationError = 'Location services are disabled. Please enable GPS.';
        _isLoadingLocation = false;
      });
      return;
    }

    // Check location permission
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationError = 'Location permission denied.';
          _isLoadingLocation = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationError = 'Location permission permanently denied. Enable in settings.';
        _isLoadingLocation = false;
      });
      return;
    }
  }

  // Step 2: Get current GPS location
  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoadingLocation = true;
        _locationError = '';
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _qiblaDirection = _calculateQiblaDirection(
          position.latitude,
          position.longitude,
        );
        _isLoadingLocation = false;
      });

      debugPrint('Location: ${position.latitude}, ${position.longitude}');
      debugPrint('Qibla Direction: $_qiblaDirection°');
    } catch (e) {
      setState(() {
        _locationError = 'Failed to get location: $e';
        _isLoadingLocation = false;
      });
      debugPrint('Location error: $e');
    }
  }

  // Step 3: Calculate Qibla direction using Haversine formula
  double _calculateQiblaDirection(double userLat, double userLon) {
    // Convert degrees to radians
    double lat1 = _toRadians(userLat);
    double lon1 = _toRadians(userLon);
    double lat2 = _toRadians(meccaLat);
    double lon2 = _toRadians(meccaLon);

    // Calculate longitude difference
    double dLon = lon2 - lon1;

    // Calculate Qibla direction using formula
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x);

    // Convert radians to degrees
    double qibla = _toDegrees(bearing);

    // Normalize to 0-360 range
    qibla = (qibla + 360) % 360;

    return qibla;
  }

  // Helper: Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Helper: Convert radians to degrees
  double _toDegrees(double radians) {
    return radians * 180 / math.pi;
  }

  // Step 4: Initialize compass using magnetometer
  void _initCompass() {
    _magnetometerSubscription = magnetometerEventStream().listen(
          (MagnetometerEvent event) {
        setState(() {
          _magnetometerX = event.x;
          _magnetometerY = event.y;

          // Calculate heading from magnetometer data
          double heading = math.atan2(_magnetometerY, _magnetometerX) * (180 / math.pi);

          // Normalize to 0-360 range
          heading = (heading + 360) % 360;

          // Convert to compass heading (0° = North)
          _currentHeading = (90 - heading + 360) % 360;
        });
      },
      onError: (error) {
        debugPrint('Magnetometer error: $error');
      },
    );
  }

  @override
  void dispose() {
    _magnetometerSubscription?.cancel();
    super.dispose();
  }

  // Calculate angle difference between current heading and Qibla
  double _getAngleToQibla() {
    double diff = (_qiblaDirection - _currentHeading + 360) % 360;
    return diff > 180 ? diff - 360 : diff;
  }

  @override
  Widget build(BuildContext context) {
    final angleToQibla = _getAngleToQibla();
    final isAligned = angleToQibla.abs() < 5;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Qibla Direction'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingLocation
          ? _buildLoadingWidget()
          : _locationError.isNotEmpty
          ? _buildErrorWidget()
          : _buildCompassWidget(angleToQibla, isAligned),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        backgroundColor: Colors.teal,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  // Loading widget while fetching location
  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.teal),
          const SizedBox(height: 20),
          const Text(
            'Getting your location...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please ensure GPS is enabled',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Error widget when location fails
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 20),
            Text(
              _locationError,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _getCurrentLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Main compass widget
  Widget _buildCompassWidget(double angleToQibla, bool isAligned) {
    return Column(
      children: [
        // Location & Info section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade400, Colors.teal.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Location info
              if (_currentPosition != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on, color: Colors.white70, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}°, '
                          'Lon: ${_currentPosition!.longitude.toStringAsFixed(4)}°',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Heading info
              Text(
                'Current: ${_currentHeading.toStringAsFixed(1)}°',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Qibla: ${_qiblaDirection.toStringAsFixed(1)}°',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),

              // Alignment status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isAligned ? Colors.green : Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isAligned
                      ? 'ALIGNED! ✓'
                      : 'Turn ${angleToQibla > 0 ? "Right" : "Left"} ${angleToQibla.abs().toStringAsFixed(1)}°',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isAligned ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Compass gauge
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 360,
                    startAngle: 270,
                    endAngle: 270,
                    interval: 30,
                    radiusFactor: 0.9,
                    showAxisLine: true,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 20,
                      color: Color(0xFFEEEEEE),
                      thicknessUnit: GaugeSizeUnit.logicalPixel,
                    ),
                    showLabels: false,
                    showTicks: true,
                    majorTickStyle: const MajorTickStyle(
                      length: 12,
                      thickness: 2,
                      color: Color(0xFF424242),
                    ),
                    minorTickStyle: const MinorTickStyle(
                      length: 6,
                      thickness: 1,
                      color: Color(0xFF757575),
                    ),
                    minorTicksPerInterval: 2,

                    ranges: <GaugeRange>[
                      // Qibla direction highlight range
                      GaugeRange(
                        startValue: (_qiblaDirection - 10 + 360) % 360,
                        endValue: (_qiblaDirection + 10) % 360,
                        color: Colors.green.withOpacity(0.3),
                        startWidth: 20,
                        endWidth: 20,
                      ),
                    ],

                    pointers: <GaugePointer>[
                      // Qibla direction marker (static)
                      MarkerPointer(
                        value: _qiblaDirection,
                        markerType: MarkerType.triangle,
                        color: Colors.green,
                        markerHeight: 20,
                        markerWidth: 20,
                        markerOffset: -10,
                      ),
                      // Current heading needle (rotates with phone)
                      NeedlePointer(
                        value: _currentHeading,
                        needleColor: Colors.red.shade600,
                        needleLength: 0.75,
                        needleStartWidth: 2,
                        needleEndWidth: 8,
                        knobStyle: KnobStyle(
                          knobRadius: 0.07,
                          sizeUnit: GaugeSizeUnit.factor,
                          color: Colors.red.shade600,
                          borderColor: Colors.white,
                          borderWidth: 3,
                        ),
                        enableAnimation: false,
                      ),
                    ],

                    annotations: <GaugeAnnotation>[
                      // North
                      GaugeAnnotation(
                        widget: const Text(
                          'N',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        angle: 0,
                        positionFactor: 0.75,
                      ),
                      // East
                      GaugeAnnotation(
                        widget: const Text(
                          'E',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242),
                          ),
                        ),
                        angle: 90,
                        positionFactor: 0.75,
                      ),
                      // South
                      GaugeAnnotation(
                        widget: const Text(
                          'S',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242),
                          ),
                        ),
                        angle: 180,
                        positionFactor: 0.75,
                      ),
                      // West
                      GaugeAnnotation(
                        widget: const Text(
                          'W',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF424242),
                          ),
                        ),
                        angle: 270,
                        positionFactor: 0.75,
                      ),
                      // Center degree display
                      GaugeAnnotation(
                        widget: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            '${_currentHeading.toStringAsFixed(0)}°',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ),
                        angle: 90,
                        positionFactor: 0.0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Instructions
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'How to use:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Hold your phone flat (parallel to ground)\n'
                        '2. Red needle shows your current direction\n'
                        '3. Green triangle marks Qibla direction\n'
                        '4. Rotate until red needle aligns with green triangle',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
