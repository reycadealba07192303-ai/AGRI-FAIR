import 'api_client.dart';

/// A province, city or municipality, as the picker needs it.
class Place {
  const Place({required this.code, required this.name, this.oldName = ''});

  final String code;
  final String name;

  /// A former name, where the PSGC records one - so someone searching for
  /// what a place used to be called still finds it.
  final String oldName;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return name.toLowerCase().contains(q) || oldName.toLowerCase().contains(q);
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      oldName: (json['oldName'] ?? '').toString(),
    );
  }
}

/// Philippine places, from our own backend rather than a third party.
///
/// Each answer is kept for the life of the app run: a picker reopened while
/// filling in one address should not refetch the same list, and the places of
/// the Philippines do not change between two taps.
class GeoService {
  GeoService._();

  static final GeoService instance = GeoService._();

  final _api = ApiClient.instance;

  List<Place>? _provinces;
  final _cities = <String, List<Place>>{};
  final _barangays = <String, List<String>>{};

  List<Place> _places(dynamic body) {
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(Place.fromJson)
        .where((p) => p.code.isNotEmpty)
        .toList();
  }

  Future<List<Place>> provinces() async {
    return _provinces ??= _places(await _api.get('/geo/provinces'));
  }

  Future<List<Place>> cities(String provinceCode) async {
    if (_cities.containsKey(provinceCode)) return _cities[provinceCode]!;

    final list = _places(await _api.get('/geo/provinces/$provinceCode/cities'));
    return _cities[provinceCode] = list;
  }

  /// Barangays are names only - nothing here addresses one by code.
  Future<List<String>> barangays(String cityCode) async {
    if (_barangays.containsKey(cityCode)) return _barangays[cityCode]!;

    final body = await _api.get('/geo/cities/$cityCode/barangays');
    final list = body is List ? body.map((e) => e.toString()).toList() : <String>[];

    return _barangays[cityCode] = list;
  }
}
