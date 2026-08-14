import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:intravel/models/weather_model.dart';
import 'package:intravel/services/weather_service.dart';

void main() {
  group('WeatherCondition.fromWmoCode', () {
    test('maps clear-sky code to clear', () {
      expect(WeatherCondition.fromWmoCode(0), WeatherCondition.clear);
    });

    test('maps partly-cloudy codes to mainlyClear', () {
      expect(WeatherCondition.fromWmoCode(1), WeatherCondition.mainlyClear);
      expect(WeatherCondition.fromWmoCode(2), WeatherCondition.mainlyClear);
    });

    test('maps rain codes to rain', () {
      expect(WeatherCondition.fromWmoCode(61), WeatherCondition.rain);
      expect(WeatherCondition.fromWmoCode(80), WeatherCondition.rain);
    });

    test('maps thunderstorm codes to thunderstorm', () {
      expect(WeatherCondition.fromWmoCode(95), WeatherCondition.thunderstorm);
    });

    test('maps unrecognized codes to unknown', () {
      expect(WeatherCondition.fromWmoCode(999), WeatherCondition.unknown);
    });
  });

  group('WeatherSnapshot', () {
    test('temperatureLabel rounds to the nearest degree with a ° suffix', () {
      const snapshot = WeatherSnapshot(
        temperatureCelsius: 28.6,
        condition: WeatherCondition.partlyCloudy,
      );
      expect(snapshot.temperatureLabel, '29°');
    });
  });

  test('Open-Meteo response shape parses into the expected fields', () {
    // Mirrors the actual `current` block shape returned by
    // https://api.open-meteo.com/v1/forecast?current=temperature_2m,weather_code
    final body = jsonEncode({
      'current': {'temperature_2m': 29.4, 'weather_code': 2},
    });
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final current = decoded['current'] as Map<String, dynamic>;
    final temperature = (current['temperature_2m'] as num).toDouble();
    final weatherCode = (current['weather_code'] as num).toInt();

    final snapshot = WeatherSnapshot(
      temperatureCelsius: temperature,
      condition: WeatherCondition.fromWmoCode(weatherCode),
    );

    expect(snapshot.temperatureLabel, '29°');
    expect(snapshot.condition.label, 'Partly Cloudy');
  });

  group('WeatherService.fetchCurrent', () {
    test('parses a successful Open-Meteo response', () async {
      final service = WeatherService();
      service.setClientForTesting(
        MockClient((request) async {
          expect(request.url.host, 'api.open-meteo.com');
          return http.Response(
            jsonEncode({
              'current': {'temperature_2m': 31.2, 'weather_code': 61},
            }),
            200,
          );
        }),
      );

      final snapshot = await service.fetchCurrent(
        latitude: 14.5906,
        longitude: 120.9750,
      );

      expect(snapshot.temperatureCelsius, 31.2);
      expect(snapshot.condition, WeatherCondition.rain);
    });

    test('throws WeatherException on a non-200 response', () async {
      final service = WeatherService();
      service.setClientForTesting(
        MockClient((request) async => http.Response('', 500)),
      );

      await expectLater(
        service.fetchCurrent(latitude: 14.5906, longitude: 120.9750),
        throwsA(isA<WeatherException>()),
      );
    });

    test('throws WeatherException when the request throws', () async {
      final service = WeatherService();
      service.setClientForTesting(
        MockClient((request) async {
          throw Exception('connection refused');
        }),
      );

      await expectLater(
        service.fetchCurrent(latitude: 14.5906, longitude: 120.9750),
        throwsA(isA<WeatherException>()),
      );
    });
  });
}
