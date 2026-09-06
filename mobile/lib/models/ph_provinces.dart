/// The provinces of the Philippines, plus Metro Manila.
///
/// A fixed list is worth having here: a province typed by hand comes back as
/// "Nueva Ecjia" or "N. Ecija" often enough to matter when a rider is reading
/// it, and it is a small enough set to be certain of.
///
/// City and barangay stay free text on purpose. There are around 1,600
/// municipalities and 42,000 barangays; a list of those written from memory
/// would put wrong places into real addresses, which is worse than typing.
class PhProvinces {
  const PhProvinces._();

  /// Not a province - a region - but it is what someone in Manila will look
  /// for, and leaving it out makes the list feel broken.
  static const metroManila = 'Metro Manila';

  static const all = <String>[
    metroManila,

    // Cordillera Administrative Region
    'Abra',
    'Apayao',
    'Benguet',
    'Ifugao',
    'Kalinga',
    'Mountain Province',

    // Ilocos Region
    'Ilocos Norte',
    'Ilocos Sur',
    'La Union',
    'Pangasinan',

    // Cagayan Valley
    'Batanes',
    'Cagayan',
    'Isabela',
    'Nueva Vizcaya',
    'Quirino',

    // Central Luzon
    'Aurora',
    'Bataan',
    'Bulacan',
    'Nueva Ecija',
    'Pampanga',
    'Tarlac',
    'Zambales',

    // CALABARZON
    'Batangas',
    'Cavite',
    'Laguna',
    'Quezon',
    'Rizal',

    // MIMAROPA
    'Marinduque',
    'Occidental Mindoro',
    'Oriental Mindoro',
    'Palawan',
    'Romblon',

    // Bicol Region
    'Albay',
    'Camarines Norte',
    'Camarines Sur',
    'Catanduanes',
    'Masbate',
    'Sorsogon',

    // Western Visayas
    'Aklan',
    'Antique',
    'Capiz',
    'Guimaras',
    'Iloilo',
    'Negros Occidental',

    // Central Visayas
    'Bohol',
    'Cebu',
    'Negros Oriental',
    'Siquijor',

    // Eastern Visayas
    'Biliran',
    'Eastern Samar',
    'Leyte',
    'Northern Samar',
    'Samar',
    'Southern Leyte',

    // Zamboanga Peninsula
    'Zamboanga del Norte',
    'Zamboanga del Sur',
    'Zamboanga Sibugay',

    // Northern Mindanao
    'Bukidnon',
    'Camiguin',
    'Lanao del Norte',
    'Misamis Occidental',
    'Misamis Oriental',

    // Davao Region
    'Davao de Oro',
    'Davao del Norte',
    'Davao del Sur',
    'Davao Occidental',
    'Davao Oriental',

    // SOCCSKSARGEN
    'Cotabato',
    'Sarangani',
    'South Cotabato',
    'Sultan Kudarat',

    // Caraga
    'Agusan del Norte',
    'Agusan del Sur',
    'Dinagat Islands',
    'Surigao del Norte',
    'Surigao del Sur',

    // Bangsamoro
    'Basilan',
    'Lanao del Sur',
    'Maguindanao del Norte',
    'Maguindanao del Sur',
    'Sulu',
    'Tawi-Tawi',
  ];

  /// Older names people still search by, mapped to what the list calls them.
  static const _alsoKnownAs = <String, String>{
    'compostela valley': 'Davao de Oro',
    'north cotabato': 'Cotabato',
    'maguindanao': 'Maguindanao del Norte',
    'ncr': metroManila,
    'manila': metroManila,
    'mm': metroManila,
  };

  /// Matches on the name or on a former one, so someone typing "Compostela
  /// Valley" still finds Davao de Oro.
  static List<String> search(String term) {
    final query = term.trim().toLowerCase();
    if (query.isEmpty) return all;

    final aliased = _alsoKnownAs.entries
        .where((e) => e.key.contains(query))
        .map((e) => e.value)
        .toSet();

    return all
        .where((p) => p.toLowerCase().contains(query) || aliased.contains(p))
        .toList();
  }
}
