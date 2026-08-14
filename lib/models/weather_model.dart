/// A single real-time weather reading for a location, returned by
/// [WeatherService]. Backed by Open-Meteo (see `lib/services/weather_service.dart`
/// for why — free, no API key/billing, unlike Google Weather).
class WeatherSnapshot {
  /// Current temperature in Celsius.
  final double temperatureCelsius;

  /// Human-readable condition label derived from the WMO weather code
  /// (e.g. "Partly Cloudy", "Light Rain") — see [WeatherCondition].
  final WeatherCondition condition;

  const WeatherSnapshot({
    required this.temperatureCelsius,
    required this.condition,
  });

  /// Rounded display string, e.g. "29°".
  String get temperatureLabel => '${temperatureCelsius.round()}°';
}

/// Maps Open-Meteo's WMO weather codes to a label + emoji glyph, grouped
/// into the handful of conditions relevant for a user-facing summary.
/// Reference: https://open-meteo.com/en/docs (WMO Weather interpretation
/// codes table).
enum WeatherCondition {
  clear,
  mainlyClear,
  partlyCloudy,
  overcast,
  fog,
  drizzle,
  rain,
  snow,
  thunderstorm,
  unknown;

  static WeatherCondition fromWmoCode(int code) {
    switch (code) {
      case 0:
        return WeatherCondition.clear;
      case 1:
      case 2:
        return WeatherCondition.mainlyClear;
      case 3:
        return WeatherCondition.overcast;
      case 45:
      case 48:
        return WeatherCondition.fog;
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return WeatherCondition.drizzle;
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
      case 80:
      case 81:
      case 82:
        return WeatherCondition.rain;
      case 71:
      case 73:
      case 75:
      case 77:
      case 85:
      case 86:
        return WeatherCondition.snow;
      case 95:
      case 96:
      case 99:
        return WeatherCondition.thunderstorm;
      default:
        return WeatherCondition.unknown;
    }
  }

  String get label {
    switch (this) {
      case WeatherCondition.clear:
        return 'Clear';
      case WeatherCondition.mainlyClear:
        return 'Partly Cloudy';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.overcast:
        return 'Overcast';
      case WeatherCondition.fog:
        return 'Foggy';
      case WeatherCondition.drizzle:
        return 'Drizzle';
      case WeatherCondition.rain:
        return 'Rainy';
      case WeatherCondition.snow:
        return 'Snow';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorms';
      case WeatherCondition.unknown:
        return 'Weather';
    }
  }

  /// Emoji glyph shown in the weather card, matching the app's existing
  /// plain-glyph style (no icon asset dependency).
  String get glyph {
    switch (this) {
      case WeatherCondition.clear:
        return '☀';
      case WeatherCondition.mainlyClear:
      case WeatherCondition.partlyCloudy:
        return '⛅';
      case WeatherCondition.overcast:
        return '☁';
      case WeatherCondition.fog:
        return '🌫';
      case WeatherCondition.drizzle:
        return '🌦';
      case WeatherCondition.rain:
        return '🌧';
      case WeatherCondition.snow:
        return '❄';
      case WeatherCondition.thunderstorm:
        return '⛈';
      case WeatherCondition.unknown:
        return '☁';
    }
  }
}
