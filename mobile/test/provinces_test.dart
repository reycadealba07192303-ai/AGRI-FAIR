import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/ph_provinces.dart';

void main() {
  test('the list holds all 82 provinces plus Metro Manila', () {
    expect(PhProvinces.all, hasLength(83));
    expect(PhProvinces.all.toSet(), hasLength(83), reason: 'no duplicates');
  });

  test('a few from every island group are present', () {
    for (final province in [
      'Nueva Ecija',
      'Ilocos Norte',
      'Batanes',
      'Palawan',
      'Cebu',
      'Iloilo',
      'Leyte',
      'Bukidnon',
      'Davao del Sur',
      'Tawi-Tawi',
    ]) {
      expect(PhProvinces.all, contains(province));
    }
  });

  test('search matches part of a name', () {
    expect(PhProvinces.search('ecija'), ['Nueva Ecija']);
    expect(PhProvinces.search('davao'), hasLength(5));
  });

  test('search ignores case', () {
    expect(PhProvinces.search('CEBU'), contains('Cebu'));
    expect(PhProvinces.search('cebu'), contains('Cebu'));
  });

  test('an old name still finds the province', () {
    // Renamed in 2019. Someone who has always called it Compostela Valley
    // should not conclude their province is missing.
    expect(PhProvinces.search('compostela'), contains('Davao de Oro'));
    expect(PhProvinces.search('north cotabato'), contains('Cotabato'));
  });

  test('Metro Manila is findable by the names people use for it', () {
    expect(PhProvinces.search('ncr'), contains('Metro Manila'));
    expect(PhProvinces.search('manila'), contains('Metro Manila'));
  });

  test('an empty search shows everything, not nothing', () {
    expect(PhProvinces.search(''), hasLength(83));
    expect(PhProvinces.search('   '), hasLength(83));
  });

  test('a term that matches nothing returns empty, not everything', () {
    expect(PhProvinces.search('zzzzz'), isEmpty);
  });
}
