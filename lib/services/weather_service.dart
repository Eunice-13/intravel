import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;

import '../models/weather_model.dart';

/// Fetches real-time weather for a location via the Open-Meteo Forecast
/// API (https://open-meteo.com/) — chosen over Google's Weather API
/// because Open-Meteo is free with no API key and no billing account
/// required, matching this app's existing preference for free/keyless
/// services (OpenRouteService instead of Google Directions, OSM tiles
/// instead of paid tile providers elsewhere in the app) instead of adding
/// another billed Google Cloud dependency on top of the Maps SDK key
/// already required elsewhere.
///
/// Throws a [WeatherException] on any failure — callers must handle it and
/// show a graceful fallback rather than crashing.
class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  http.Client _client = http.Client();

  /// Overrides the internal HTTP client — for tests only, so they can
  /// supply a fake/mock client instead of making real network calls.
  @visibleForTesting
  void setClientForTesting(http.Client client) {
    _client = client;
  }

  /// Fetches the current temperature + condition for [latitude]/[longitude].
  Future<WeatherSnapshot> fetchCurrent({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current': 'temperature_2m,weather_code',
      },
    );

    http.Response response;
    try {
      response = await _client.get(uri).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw WeatherException(
        'Could not reach the weather service. Check your connection.',
        cause: e,
      );
    }

    if (response.statusCode != 200) {
      throw WeatherException(
        'Weather request failed (HTTP ${response.statusCode}).',
        cause: response.body,
      );
    }

    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final current = decoded['current'] as Map<String, dynamic>;
      final temperature = (current['temperature_2m'] as num).toDouble();
      final weatherCode = (current['weather_code'] as num).toInt();
      return WeatherSnapshot(
        temperatureCelsius: temperature,
        condition: WeatherCondition.fromWmoCode(weatherCode),
      );
    } catch (e) {
      throw WeatherException(
        'Could not parse the weather response.',
        cause: e,
      );
    }
  }
}

class WeatherException implements Exception {
  final String message;
  final Object? cause;

  const WeatherException(this.message, {this.cause});

  @override
  String toString() => 'WeatherException: $message';
}
