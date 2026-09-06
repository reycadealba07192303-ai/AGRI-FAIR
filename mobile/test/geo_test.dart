import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/geo_service.dart';

/// Philippine places, from the backend. Needs the server running with the
/// PSGC data built: node src/scripts/buildPsgc.js
void main() {
  final geo = GeoService.instance;

  test('every province is listed, Metro Manila included', () async {
    final provinces = await geo.provinces();

    expect(provinces, hasLength(82));
    expect(provinces.map((p) => p.name), contains('Nueva Ecija'));
    // Not a province, but where someone in Manila will look for their city.
    expect(provinces.map((p) => p.name), contains('Metro Manila'));
  });

  test('a province returns its own cities', () async {
    final provinces = await geo.provinces();
    final ne = provinces.firstWhere((p) => p.name == 'Nueva Ecija');

    final cities = await geo.cities(ne.code);

    expect(cities, isNotEmpty);
    expect(cities.map((c) => c.name), contains('City of Cabanatuan'));
  });

  test('Metro Manila has its cities despite having no province code', () async {
    final cities = await geo.cities('NCR');

    expect(cities, hasLength(17));
    expect(cities.map((c) => c.name), contains('City of Manila'));
  });

  test('the two provinceless cities are reachable', () async {
    // Both are administratively outside the province they sit in, and would
    // be unreachable in a province-then-city picker without being filed.
    final basilan = await geo.provinces().then(
          (list) => list.firstWhere((p) => p.name == 'Basilan'),
        );
    expect(
      (await geo.cities(basilan.code)).map((c) => c.name),
      contains('City of Isabela'),
    );

    final maguindanao = await geo.provinces().then(
          (list) => list.firstWhere((p) => p.name.startsWith('Maguindanao')),
        );
    expect(
      (await geo.cities(maguindanao.code)).map((c) => c.name),
      contains('City of Cotabato'),
    );
  });

  test('a city returns its barangays', () async {
    final ne = await geo.provinces().then(
          (list) => list.firstWhere((p) => p.name == 'Nueva Ecija'),
        );
    final cabanatuan = await geo
        .cities(ne.code)
        .then((list) => list.firstWhere((c) => c.name.contains('Cabanatuan')));

    final barangays = await geo.barangays(cabanatuan.code);

    expect(barangays, isNotEmpty);
    expect(barangays, contains('Aduas Centro'));
  });

  test('a second call for the same list does not go to the network', () async {
    final ne = await geo.provinces().then(
          (list) => list.firstWhere((p) => p.name == 'Nueva Ecija'),
        );

    await geo.cities(ne.code);

    final watch = Stopwatch()..start();
    await geo.cities(ne.code);
    watch.stop();

    // Reopening a picker while filling in one address should not refetch.
    expect(watch.elapsedMilliseconds, lessThan(20));
  });

  test('an unknown code is refused rather than returning everything', () async {
    await expectLater(
      geo.cities('NOPE'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)),
    );
  });

  test('search matches a former name', () {
    const place = Place(
      code: '1',
      name: 'Davao de Oro',
      oldName: 'Compostela Valley',
    );

    expect(place.matches('compostela'), isTrue);
    expect(place.matches('davao'), isTrue);
    expect(place.matches('cebu'), isFalse);
  });
}
