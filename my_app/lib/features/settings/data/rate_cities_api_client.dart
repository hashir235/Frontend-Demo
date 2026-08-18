import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/network/auth_http_client.dart';
import '../models/pakistan_cities.dart';

/// Which cities the owner has published a rate list for.
///
/// Asked before a workshop settles on a city, so someone in a city with no
/// list is told so and given a number to ring — rather than quietly ending up
/// on another city's prices, which is the one thing they could never spot from
/// inside the app.
class RateCitiesAvailability {
  /// Slugs of the cities that have their own list.
  final Set<String> citySlugs;

  /// Whether the original single list is still there for cities without one.
  final bool hasFallback;

  /// Where to send someone whose city is missing.
  final String supportPhone;

  const RateCitiesAvailability({
    required this.citySlugs,
    required this.hasFallback,
    required this.supportPhone,
  });

  /// What to assume when the server could not be reached.
  ///
  /// Empty rather than "everything is available": claiming a list exists when
  /// we do not know would send a workshop away thinking their rates are right.
  /// Callers treat [known] as false and simply say nothing.
  const RateCitiesAvailability.unknown()
    : citySlugs = const <String>{},
      hasFallback = true,
      supportPhone = '';

  bool get known => supportPhone.isNotEmpty;

  bool hasListFor(String city) =>
      citySlugs.contains(PakistanCities.slug(city));

  factory RateCitiesAvailability.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw =
        (json['cities'] as List<dynamic>?) ?? const <dynamic>[];
    return RateCitiesAvailability(
      citySlugs: raw.map((dynamic e) => '$e'.trim()).toSet(),
      hasFallback: json['hasFallback'] != false,
      supportPhone: (json['supportPhone'] as String? ?? '').trim(),
    );
  }
}

class RateCitiesApiClient {
  final AuthHttpClient _client;

  RateCitiesApiClient({AuthHttpClient? client})
    : _client = client ?? AuthHttpClient();

  Future<RateCitiesAvailability> fetch() async {
    try {
      final http.Response response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/api/settings/rate-cities'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const RateCitiesAvailability.unknown();
      }
      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (body['ok'] == false) return const RateCitiesAvailability.unknown();
      return RateCitiesAvailability.fromJson(body);
    } catch (_) {
      // Setting up a workshop must not fail because this lookup did.
      return const RateCitiesAvailability.unknown();
    }
  }
}
