import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationScreen extends StatefulWidget {
  const GeolocationScreen({Key? key}) : super(key: key);

  @override
  _GeolocationScreenState createState() => _GeolocationScreenState();
}

class _GeolocationScreenState extends State<GeolocationScreen> {
  bool _isGeolocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadGeolocationSetting();
  }

  Future<void> _loadGeolocationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isGeolocationEnabled = prefs.getBool('geolocationEnabled') ?? false;
    });
  }

  Future<void> _saveGeolocationSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('geolocationEnabled', value);
    setState(() {
      _isGeolocationEnabled = value;
    });
  }

  Future<void> _requestLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем, включены ли службы геолокации
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, включите службы геолокации')),
      );
      return;
    }

    // Запрашиваем разрешение
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Разрешение на геолокацию отклонено')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Разрешение на геолокацию отклонено навсегда')),
      );
      return;
    }

    // Если разрешение получено, сохраняем настройку
    await _saveGeolocationSetting(true);
  }

  Future<void> _toggleGeolocation(bool value) async {
    if (value) {
      await _requestLocationPermission();
    } else {
      await _saveGeolocationSetting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Геолокация', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Настройки геолокации',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('Использовать геолокацию'),
              subtitle: const Text('Разрешить приложению доступ к местоположению'),
              value: _isGeolocationEnabled,
              onChanged: (bool value) async {
                await _toggleGeolocation(value);
              },
              activeColor: Colors.blue,
            ),
          ],
        ),
      ),
    );
  }
}