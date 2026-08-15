import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';

/// Lightweight, unstyled site record mirroring the `touristSites` /
/// `siteProfiles` / `officialVisitFacts` datasets in the Eunice-branch web
/// dashboard (assets/intravel/index.html). Kept private to this file; use
/// [LocationService] to get fully-built [LocationModel]s.
class _RawSite {
  final String id;
  final String name;
  final String
  category; // Fortifications | Landmarks | Museums | Churches | Parks | Cafe
  final String type;
  final String note;
  final String access;
  final String photo; // asset path or network URL
  final String area;
  final String history;
  final List<String> highlights;
  final String visitNote;
  final LatLng coordinates;
  final List<String> relatedPlaceIds;
  final OperatingHours? officialHours;
  final TicketInfo? officialTicket;

  /// Whether this site (Cafe category) offers WiFi (addendum spec 3
  /// Section 2.2). Defaults to `false` for non-cafe categories.
  final bool hasWifi;

  /// Whether this site (Cafe category) offers power sockets/outlets for
  /// laptops and devices (addendum spec 3 Section 2.2). Defaults to
  /// `false` for non-cafe categories.
  final bool hasSockets;

  /// Realistic per-person spending range (addendum spec 3.5). Every site
  /// gets one, including free/exterior sites, which still carry a small
  /// incidental-spend range rather than defaulting to ₱0.
  final BudgetRange budgetRange;

  const _RawSite({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.note,
    required this.access,
    required this.photo,
    required this.area,
    required this.history,
    required this.highlights,
    required this.visitNote,
    required this.coordinates,
    this.relatedPlaceIds = const [],
    this.officialHours,
    this.officialTicket,
    this.hasWifi = false,
    this.hasSockets = false,
    required this.budgetRange,
  });
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // ─── Raw site catalogue (ported from Eunice-branch touristSites) ───────────
  static final List<_RawSite> _rawSites = [
    _RawSite(
      id: 'fort-santiago',
      budgetRange: const BudgetRange(min: 50, max: 75),
      name: 'Fort Santiago',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Main citadel and heritage park',
      access: 'Entry ticket',
      photo: 'assets/intravel/assets/home/fort-santiago.jpg',
      area: 'Northern Intramuros',
      history:
          'Built in 1571 by Miguel Lopez de Legazpi, Fort Santiago was the seat of Spanish colonial power for more than 300 years. Jose Rizal was imprisoned in its dungeons before his execution on 30 December 1896. During the Second World War, Filipino and American prisoners of war died in its tidal dungeons.',
      highlights: [
        'The main gate and Plaza de Armas',
        'Rizal Shrine and the Rizal memorial trail',
        'Riverside ramparts facing the Pasig River',
      ],
      visitNote:
          'Hours and fees are shown from the Intramuros Administration schedule and may change for weather, events, or special bookings. Check the official notice before travelling.',
      // Verified against the main gate/entrance (not the fort's geometric
      // centroid), cross-checked between OSM way data and the existing
      // pois.json "Fort Santiago Gate" entry: 14.593865, 120.9707241.
      coordinates: const LatLng(14.5939, 120.9707),
      relatedPlaceIds: [
        'museo-ni-rizal',
        'plaza-de-armas',
        'fort-santiago-riverwalk',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [1, 2, 3, 4, 5],
            openMinutes: 480,
            closeMinutes: 1320,
            lastEntryMinutes: 1260,
          ),
          DaySchedule(days: [6, 7], openMinutes: 360, closeMinutes: 1320),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 75,
        studentPrice: 50,
        seniorPrice: 50,
        currency: '₱',
        notes: 'Free for children under 3',
      ),
    ),
    _RawSite(
      id: 'museo-ni-rizal',
      budgetRange: const BudgetRange(min: 50, max: 75),
      name: 'Museo ni Rizal (Rizal Shrine)',
      category: 'Museums',
      type: 'Museum',
      note: 'Inside Fort Santiago',
      access: 'Fort entry',
      photo: 'assets/intravel/assets/home/ia-museo-ni-rizal.jpg',
      area: 'Inside Fort Santiago',
      history:
          "This shrine occupies the area associated with Jose Rizal's final imprisonment before his execution in 1896. It interprets his life, writings, and final days within the fort.",
      highlights: [
        'Rizal-related exhibits and memorabilia',
        'The final-walk memorial trail',
        'Fort Santiago surroundings',
      ],
      visitNote:
          'Entry conditions follow Fort Santiago visitor rules. Confirm current museum access before your visit.',
      // OSM way 27275508 "Rizal Shrine" (wikidata Q7339081), inside Fort
      // Santiago: 14.59451, 120.96971. Previous value sat ~215m east, out
      // by the fort's Almacenes side rather than at the shrine building.
      coordinates: const LatLng(14.5945, 120.9697),
      relatedPlaceIds: [
        'fort-santiago',
        'plaza-de-armas',
        'fort-santiago-riverwalk',
      ],
    ),
    _RawSite(
      id: 'fort-santiago-riverwalk',
      budgetRange: const BudgetRange(min: 20, max: 70),
      name: 'Fort Santiago Riverwalk',
      category: 'Parks',
      type: 'Riverwalk',
      note: 'Riverside walls and Pasig views',
      access: 'Free',
      photo: 'assets/intravel/assets/home/ia-fort-riverwalk.jpg',
      area: 'Fort Santiago river side',
      history:
          'Opened in 2025, the Fort Santiago Riverwalk opens the riverside walls of Fort Santiago and connects visitors toward the Pasig River Esplanade.',
      highlights: [
        'Views toward the Pasig River',
        'Fort walls from the river side',
        'A walking connection toward the esplanade',
      ],
      visitNote:
          'Use designated paths and observe on-site safety guidance, especially after rain or during maintenance.',
      // OSM way 1359419593 "Esplanade - Fort Santiago": 14.59488,
      // 120.97101. The previous value was north of the south bank, i.e.
      // in the Pasig itself.
      coordinates: const LatLng(14.5949, 120.9710),
      relatedPlaceIds: [
        'fort-santiago',
        'pasig-river-esplanade',
        'plaza-moriones',
      ],
    ),
    _RawSite(
      id: 'pasig-river-esplanade',
      budgetRange: const BudgetRange(min: 20, max: 70),
      name: 'Pasig River Esplanade',
      category: 'Parks',
      type: 'Promenade',
      note: 'Riverside public walk',
      access: 'Free',
      photo: 'assets/intravel/assets/home/ia-pasig-esplanade.jpg',
      area: 'Pasig River waterfront',
      history:
          "The Pasig River Esplanade is a public riverfront promenade that reconnects people with Manila's historic waterway and reaches toward the Intramuros side of the river.",
      highlights: [
        'River and city views',
        'Public promenade space',
        'Connection toward Fort Santiago',
      ],
      visitNote:
          'This is an outdoor public space. Check weather, closures, and local advisories before visiting.',
      // OSM way 1336921368 "Esplanade - Intramuros": 14.59502, 120.97623
      // — the Intramuros-side stretch of the riverwalk. The previous value
      // was in the middle of the Pasig.
      coordinates: const LatLng(14.5950, 120.9762),
      relatedPlaceIds: [
        'fort-santiago-riverwalk',
        'fort-santiago',
        'plaza-moriones',
      ],
    ),
    _RawSite(
      id: 'casa-manila-museum',
      budgetRange: const BudgetRange(min: 50, max: 75),
      name: 'Casa Manila Museum',
      category: 'Museums',
      type: 'Museum',
      note: 'Late Spanish-period lifestyle museum',
      access: 'Admission',
      photo: 'assets/intravel/assets/home/casa-manila.jpg',
      area: 'Plaza San Luis Complex',
      history:
          'Casa Manila is a reconstructed bahay na bato that presents domestic life of an affluent Filipino family during the late Spanish colonial period.',
      highlights: [
        'Period rooms and furnishings',
        'Bahay na bato architecture',
        'Plaza San Luis streetscape',
      ],
      visitNote:
          'Museum admission and opening schedules are managed on site; confirm the latest visitor information before travelling.',
      // OSM way 762415668 "Casa Manila" (wikidata Q2110598): 14.58966,
      // 120.97517 — General Luna cor. Urdaneta, ~125m east of the
      // previous value.
      coordinates: const LatLng(14.5897, 120.9752),
      relatedPlaceIds: [
        'plaza-san-luis-complex',
        'san-agustin-church',
        'museo-de-intramuros',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [2, 3, 4, 5, 6, 7],
            openMinutes: 540,
            closeMinutes: 1080,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 75,
        studentPrice: 50,
        seniorPrice: 50,
        currency: '₱',
        notes:
            'Discounted rate covers students, seniors, PWDs, and government employees',
      ),
    ),
    _RawSite(
      id: 'plaza-san-luis-complex',
      budgetRange: const BudgetRange(min: 30, max: 120),
      name: 'Plaza San Luis Complex',
      category: 'Landmarks',
      type: 'Heritage complex',
      note: 'Historic streetscape beside Casa Manila',
      access: 'Free exterior',
      photo: 'assets/intravel/assets/home/casa-manila.jpg',
      area: 'General Luna Street',
      history:
          'Plaza San Luis is a heritage complex beside Casa Manila. Its reconstructed houses evoke the residential streetscape of old Intramuros.',
      highlights: [
        'Colonial-style house facades',
        'Casa Manila Museum',
        'Nearby cafes, shops, and heritage stops',
      ],
      visitNote:
          "The exterior complex is walkable; access to individual museums and businesses follows their own schedules.",
      // OSM way 72518965 "Plaza San Luis Complex": 14.58966, 120.97544.
      coordinates: const LatLng(14.5897, 120.9754),
      relatedPlaceIds: [
        'casa-manila-museum',
        'san-agustin-church',
        'san-agustin-museum',
      ],
    ),
    _RawSite(
      id: 'museo-de-intramuros',
      budgetRange: const BudgetRange(min: 120, max: 150),
      name: 'Museo de Intramuros',
      category: 'Museums',
      type: 'Museum',
      note: 'Religious art and artefacts',
      access: 'Admission',
      photo: 'assets/intravel/assets/home/museo.jpg',
      area: 'Former San Ignacio complex',
      history:
          "Museo de Intramuros presents the Intramuros Administration's collection of ecclesiastical art and artefacts in the reconstructed historic San Ignacio complex.",
      highlights: [
        'Ecclesiastical art collection',
        'Reconstructed San Ignacio setting',
        'Interpretation of Intramuros religious heritage',
      ],
      visitNote:
          "Admission, tours, and gallery availability can change. Check the museum's current visitor guidance before visiting.",
      // OSM way 89184421 "Museo de Intramuros" (wikidata Q39054929),
      // Arzobispo cor. Anda: 14.59894 → 14.58994, 120.97322.
      coordinates: const LatLng(14.5899, 120.9732),
      relatedPlaceIds: [
        'centro-de-turismo-intramuros',
        'manila-cathedral',
        'san-agustin-church',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [2, 3, 4, 5, 6, 7],
            openMinutes: 540,
            closeMinutes: 1080,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 150,
        studentPrice: 120,
        seniorPrice: 120,
        currency: '₱',
      ),
    ),
    _RawSite(
      id: 'centro-de-turismo-intramuros',
      budgetRange: const BudgetRange(min: 20, max: 60),
      name: 'Centro de Turismo Intramuros',
      category: 'Museums',
      type: 'Tourism museum',
      note: 'History hub in San Ignacio Church',
      access: 'Admission',
      photo: 'assets/intravel/assets/home/ia-centro-turismo.jpg',
      area: 'San Ignacio Church complex',
      history:
          'Opened in 2024 in the reconstructed San Ignacio Church, Centro de Turismo Intramuros introduces the history of Intramuros through exhibits and cultural activities.',
      highlights: [
        'Intramuros orientation exhibits',
        'San Ignacio Church reconstruction',
        'Cultural-programme venue',
      ],
      visitNote:
          "Confirm current exhibits, programmes, and entry arrangements with the venue before visiting.",
      // The Centro occupies the old San Ignacio Church on Arzobispo St —
      // OSM way 829052700 "San Ignacio Church" (wikidata Q18708321):
      // 14.59004, 120.97313.
      coordinates: const LatLng(14.5900, 120.9731),
      relatedPlaceIds: [
        'museo-de-intramuros',
        'manila-cathedral',
        'casa-manila-museum',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [2, 3, 4, 5, 6, 7],
            openMinutes: 540,
            closeMinutes: 1080,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 0,
        studentPrice: 0,
        currency: '₱',
        notes: 'Free admission',
      ),
    ),
    _RawSite(
      id: 'baluarte-de-san-diego',
      budgetRange: const BudgetRange(min: 50, max: 75),
      name: 'Baluarte de San Diego',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Archaeological park and garden',
      access: 'Admission',
      photo: 'assets/intravel/assets/home/baluarte-de-san-diego.jpg',
      area: 'Southwestern Intramuros',
      history:
          'Baluarte de San Diego contains the remains of the 1587 Fort Nuestra Senora de Guia, the oldest stone fort in Manila, excavated in 1979 and restored as an archaeological park.',
      highlights: [
        'Circular remains of Fort Nuestra Senora de Guia',
        'Bastion walls and archaeological layers',
        'The adjacent historic garden',
      ],
      visitNote:
          'Use designated visitor routes. Event use and access arrangements can affect availability.',
      // Verified against Wikipedia's Baluarte de San Diego coordinate
      // (14°35'07"N 120°58'32"E) and a camera-geotagged Wikimedia Commons
      // photo of the site's own entrance/gardens (14°35'10"N 120°58'31"E)
      // -- the previous value was off by roughly 300m in longitude.
      // OSM way 331628854 "Baluarte de San Diego" (wikidata Q18708349):
      // 14.58539, 120.97565.
      coordinates: const LatLng(14.5854, 120.9756),
      relatedPlaceIds: [
        'baluarte-de-san-diego-gardens',
        'puerta-real-gardens',
        'revellin-de-puerta-real-de-bagumbayan',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [1, 2, 3, 4, 5, 6, 7],
            openMinutes: 480,
            closeMinutes: 1020,
            lastEntryMinutes: 960,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 75,
        studentPrice: 50,
        seniorPrice: 50,
        currency: '₱',
        notes:
            'Discounted rate covers students, seniors, PWDs, and government employees',
      ),
    ),
    _RawSite(
      id: 'baluarte-de-san-diego-gardens',
      budgetRange: const BudgetRange(min: 20, max: 60),
      name: 'Baluarte de San Diego Gardens',
      category: 'Parks',
      type: 'Historic garden',
      note: 'Garden beside the bulwark',
      access: 'Visitor access',
      photo: 'assets/intravel/assets/home/ia-baluarte-san-diego.jpg',
      area: 'Beside Baluarte de San Diego',
      history:
          'These gardens frame the restored Baluarte de San Diego and make the historic fortification accessible as an outdoor landscape.',
      highlights: [
        'Garden views of the bastion',
        'Archaeological park setting',
        'Popular outdoor photo and event area',
      ],
      visitNote:
          'Outdoor access may be affected by weather or private events; verify access on the day of your visit.',
      // Adjacent to the corrected Baluarte de San Diego coordinate above
      // (same source: camera-geotagged Wikimedia Commons photo of the
      // gardens, 14°35'10"N 120°58'31"E) -- previous value was off by
      // roughly 300m in longitude.
      // OSM way 828352548 "Baluarte de San Diego Garden": 14.58589,
      // 120.97569.
      coordinates: const LatLng(14.5859, 120.9757),
      relatedPlaceIds: [
        'baluarte-de-san-diego',
        'puerta-real-gardens',
        'manila-cathedral',
      ],
    ),
    _RawSite(
      id: 'manila-cathedral',
      budgetRange: const BudgetRange(min: 20, max: 60),
      name: 'Manila Cathedral',
      category: 'Churches',
      type: 'Cathedral',
      note: 'Historic cathedral on Plaza Roma',
      access: 'Service times vary',
      photo: 'assets/intravel/assets/home/manila-cathedral.jpg',
      area: 'Plaza Roma',
      history:
          'The Minor Basilica and Metropolitan Cathedral of the Immaculate Conception stands at the centre of Intramuros. The present cathedral was completed in 1958 after a series of earlier churches were damaged or destroyed.',
      highlights: [
        'Romanesque Revival facade and nave',
        'Plaza Roma setting',
        'Cathedral crypt and memorials',
      ],
      visitNote:
          'This is an active place of worship. Respect services and confirm visiting hours or photography rules before entering.',
      // OSM way 331777144 "Manila Cathedral" (wikidata Q773443):
      // 14.59151, 120.97361.
      coordinates: const LatLng(14.5915, 120.9736),
      relatedPlaceIds: [
        'plaza-roma',
        'ayuntamiento-de-manila',
        'museo-de-intramuros',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [1, 2, 3, 4, 5, 6, 7],
            openMinutes: 360,
            closeMinutes: 1050,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 0,
        studentPrice: 0,
        currency: '₱',
        notes: 'Free admission, donations welcome',
      ),
    ),
    _RawSite(
      id: 'san-agustin-church',
      budgetRange: const BudgetRange(min: 20, max: 100),
      name: 'San Agustin Church',
      category: 'Churches',
      type: 'UNESCO church',
      note: 'Baroque World Heritage church',
      access: 'Service times vary',
      photo: 'assets/intravel/assets/home/san-agustin-church.jpg',
      area: 'General Luna Street',
      history:
          'San Agustin Church is the oldest surviving church structure in the Philippines and a UNESCO World Heritage Site within the Baroque Churches of the Philippines.',
      highlights: [
        'Baroque stone church interior',
        'UNESCO World Heritage architecture',
        'Historic convent complex',
      ],
      visitNote:
          'This is an active church. Service times, museum access, and photography rules are set by the church and may change.',
      // OSM way 89571506 "San Agustin Church" (wikidata Q1306513):
      // 14.58892, 120.97535.
      coordinates: const LatLng(14.5889, 120.9753),
      relatedPlaceIds: [
        'san-agustin-museum',
        'casa-manila-museum',
        'plaza-san-luis-complex',
      ],
      officialHours: const OperatingHours(
        schedules: [
          DaySchedule(
            days: [1, 2, 3, 4, 5, 6, 7],
            openMinutes: 480,
            closeMinutes: 1080,
          ),
        ],
      ),
      officialTicket: const TicketInfo(
        adultPrice: 200,
        studentPrice: 150,
        currency: '₱',
        notes: 'Museum entrance included',
      ),
    ),
    _RawSite(
      id: 'san-agustin-museum',
      budgetRange: const BudgetRange(min: 160, max: 200),
      name: 'San Agustin Museum',
      category: 'Museums',
      type: 'Museum',
      note: 'Augustinian heritage collection',
      access: 'Admission',
      photo: 'assets/intravel/assets/home/ia-san-agustin-museum.jpg',
      area: 'San Agustin complex',
      history:
          "The museum occupies the historic Augustinian complex beside San Agustin Church and interprets the order's long presence in the Philippines.",
      highlights: [
        'Religious art and church treasures',
        'Historic cloisters and corridors',
        'Connection to San Agustin Church',
      ],
      visitNote:
          'Museum hours and admission are managed separately from worship services; confirm current information before arriving.',
      // OSM way 829243249 "San Agustin Museum": 14.58856, 120.97478 —
      // the monastery wing, distinct from the church next door.
      coordinates: const LatLng(14.5886, 120.9748),
      relatedPlaceIds: [
        'san-agustin-church',
        'casa-manila-museum',
        'plaza-san-luis-complex',
      ],
      officialTicket: const TicketInfo(
        adultPrice: 200,
        studentPrice: 160,
        seniorPrice: 160,
        currency: '₱',
        notes: 'Discounted rate covers students, PWDs, and seniors',
      ),
    ),
    _RawSite(
      id: 'bahay-tsinoy',
      budgetRange: const BudgetRange(min: 60, max: 100),
      name: 'Bahay Tsinoy',
      category: 'Museums',
      type: 'Museum',
      note: 'Chinese-Filipino heritage',
      access: 'Check visitor info',
      photo: 'assets/intravel/assets/home/ia-bahay-tsinoy.jpg',
      area: 'Anda Street, Intramuros',
      history:
          'Bahay Tsinoy explores centuries of exchange between the Philippines and China and the history of the Filipino-Chinese community.',
      highlights: [
        'Chinese-Filipino history exhibits',
        'Trade and migration narratives',
        'Heritage interpretation in Intramuros',
      ],
      visitNote:
          'Check current operating status and ticket information directly with the museum before making a special trip.',
      // OSM node 11729816009 "Museum of the Chinese in Philippine Life"
      // (Bahay Tsinoy's full name), Cabildo St: 14.59090, 120.97504.
      coordinates: const LatLng(14.5909, 120.9750),
      relatedPlaceIds: [
        'plaza-san-luis-complex',
        'manila-cathedral',
        'fort-santiago',
      ],
      officialTicket: const TicketInfo(
        adultPrice: 100,
        studentPrice: 60,
        childPrice: 60,
        currency: '₱',
      ),
    ),
    _RawSite(
      id: 'destileria-limtuaco-museum',
      budgetRange: const BudgetRange(min: 100, max: 200),
      name: 'Destileria Limtuaco Museum',
      category: 'Museums',
      type: 'Museum',
      note: 'Historic distillery museum',
      access: 'Ticketed',
      photo: 'assets/intravel/assets/home/ia-destileria-limtuaco.jpg',
      area: 'San Juan de Letran area',
      history:
          'This museum tells the story of the Limtuaco family distilling business, established in the 1850s, through its products, production history, and family heritage.',
      highlights: [
        'Historic distilling story',
        'Brand and family archives',
        'Tasting or tour offerings when scheduled',
      ],
      visitNote:
          'Tours, tastings, and age restrictions may apply. Confirm current terms directly with the museum.',
      // The museum's published address is 481 San Juan de Letran St,
      // Intramuros; OSM way 217725326 puts that street at 14.59252,
      // 120.97733. The previous value (14.5975) was on the far side of the
      // Pasig River, in Binondo — outside Intramuros entirely.
      coordinates: const LatLng(14.5925, 120.9773),
      relatedPlaceIds: [
        'plaza-san-luis-complex',
        'san-agustin-church',
        'museo-de-intramuros',
      ],
      officialTicket: const TicketInfo(
        adultPrice: 100,
        studentPrice: 100,
        currency: '₱',
        notes: 'Base entrance; tasting-inclusive packages run higher',
      ),
    ),
    _RawSite(
      id: 'plaza-roma',
      budgetRange: const BudgetRange(min: 20, max: 70),
      name: 'Plaza Roma',
      category: 'Parks',
      type: 'Main square',
      note: 'Central Intramuros plaza',
      access: 'Free',
      photo: 'assets/intravel/assets/home/plaza-roma.jpg',
      area: 'Central Intramuros',
      history:
          'Formerly Plaza Mayor, Plaza Roma has long been the principal square of Intramuros. It is framed by the Manila Cathedral and civic landmarks.',
      highlights: [
        'Central square and monument',
        'Manila Cathedral frontage',
        'Access to nearby civic landmarks',
      ],
      visitNote:
          'A public open space best enjoyed on foot. Be mindful of ceremonies, traffic controls, and weather.',
      // OSM way 24159652 "Plaza de Roma": 14.59219, 120.97308.
      coordinates: const LatLng(14.5922, 120.9731),
      relatedPlaceIds: [
        'manila-cathedral',
        'ayuntamiento-de-manila',
        'palacio-del-gobernador',
      ],
    ),
    _RawSite(
      id: 'ayuntamiento-de-manila',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Ayuntamiento de Manila',
      category: 'Landmarks',
      type: 'Civic landmark',
      note: 'Reconstructed Cabildo by Plaza Roma',
      access: 'Exterior',
      photo: 'assets/intravel/assets/home/ayuntamiento.jpg',
      area: 'Plaza Roma',
      history:
          'Also called the Cabildo, the Ayuntamiento was the civic seat of colonial Manila. The present building is a reconstruction beside Plaza Roma.',
      highlights: [
        'Civic facade beside the cathedral',
        'Plaza Roma views',
        'Historic government-site context',
      ],
      visitNote:
          'This is primarily a government and historic exterior site; access beyond public areas is not assumed.',
      // Verified against OpenStreetMap's "Ayuntamiento de Manila (Casas
      // Consistoriales)" node: 14.5925078, 120.9733269.
      // OSM relation 2466078 "Ayuntamiento de Manila" (wikidata
      // Q17063849): 14.59266, 120.97365.
      coordinates: const LatLng(14.5927, 120.9736),
      relatedPlaceIds: [
        'plaza-roma',
        'manila-cathedral',
        'palacio-del-gobernador',
      ],
    ),
    _RawSite(
      id: 'palacio-del-gobernador',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Palacio del Gobernador',
      category: 'Landmarks',
      type: 'Historic site',
      note: 'Former governor-general residence site',
      access: 'Exterior',
      photo: 'assets/intravel/assets/home/palacio.jpg',
      area: 'General Luna Street',
      history:
          "The Palacio del Gobernador site marks the former Spanish-period governor-general's residence. The original structure is no longer extant.",
      highlights: [
        'Historic administrative-site context',
        'View toward Manila Cathedral and Plaza Roma',
        'Intramuros Administration vicinity',
      ],
      visitNote:
          'Treat this as an exterior landmark unless public access is explicitly announced.',
      // OSM relation 14885963 "Palacío del Gobernador" (wikidata
      // Q23821145), General Luna cor. Andres Soriano: 14.59165, 120.97252.
      coordinates: const LatLng(14.5917, 120.9725),
      relatedPlaceIds: [
        'plaza-roma',
        'ayuntamiento-de-manila',
        'manila-cathedral',
      ],
    ),
    _RawSite(
      id: 'puerta-real-gardens',
      budgetRange: const BudgetRange(min: 20, max: 70),
      name: 'Puerta Real Gardens',
      category: 'Parks',
      type: 'Historic garden',
      note: 'Royal Gate and garden',
      access: 'Free exterior',
      photo: 'assets/intravel/assets/home/ia-puerta-real-gardens.jpg',
      area: 'Southeastern Intramuros',
      history:
          'Puerta Real Gardens surrounds the restored Royal Gate and its defensive works. The gate historically connected Intramuros with Bagumbayan and Ermita.',
      highlights: [
        'Puerta Real and defensive walls',
        'Garden paths',
        'Historic approach to the Royal Gate',
      ],
      visitNote:
          'Outdoor access can change for events, maintenance, or weather. Follow posted guidance.',
      // OSM way 828320209 "Puerta Réal Gardens": 14.58585, 120.97706. The
      // previous longitude put it on the *western* seafront wall instead of
      // at Puerta Real on the south wall — roughly 360m out.
      coordinates: const LatLng(14.5859, 120.9771),
      relatedPlaceIds: [
        'baluarte-de-san-diego',
        'baluarte-de-san-diego-gardens',
        'revellin-de-puerta-real-de-bagumbayan',
      ],
    ),
    _RawSite(
      id: 'asean-gardens',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'ASEAN Gardens',
      category: 'Parks',
      type: 'Memorial garden',
      note: 'Gardens at Revellin del Parian',
      access: 'Free exterior',
      photo: 'assets/intravel/assets/home/ia-asean-gardens-corrected.png',
      area: 'Revellin del Parian area',
      history:
          'ASEAN Gardens occupies the former Revellin del Parian and commemorates the Association of Southeast Asian Nations through its landscaped memorial setting.',
      highlights: [
        'ASEAN flags and markers',
        'Revellin del Parian setting',
        'Open-air garden space',
      ],
      visitNote:
          'This is an outdoor memorial space; check local conditions and respect any event setup.',
      // OSM way 331628858 "ASEAN Garden" (alt_name "Revellin del Parian
      // Garden"): 14.59302, 120.97804. The site's own note already said
      // "Gardens at Revellin del Parian", which is on the *eastern* wall —
      // the previous value was up by the northern wall instead.
      coordinates: const LatLng(14.5930, 120.9780),
    ),
    _RawSite(
      id: 'galleria-de-los-presidentes',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Galleria de los Presidentes',
      category: 'Parks',
      type: 'Pocket park',
      note: 'Presidential bas-reliefs',
      access: 'Free',
      photo: 'assets/intravel/assets/home/ia-galleria-presidentes.jpg',
      area: 'Near Puerta de Santa Lucia',
      history:
          'Galleria de los Presidentes is a small public park displaying bas-reliefs of Philippine presidents near the historic Santa Lucia Gate.',
      highlights: [
        'Presidential bas-reliefs',
        'Nearby Santa Lucia Gate',
        'Quiet open-space stop',
      ],
      visitNote:
          'Open-air access is generally the focus; observe any posted site restrictions.',
      // Not mapped in OSM and no published coordinate found, so this is a
      // deliberate approximation rather than a verified fix: placed on the
      // wall walk just inside Puerta Real, beside Puerta Real Gardens (OSM
      // way 828320209, 14.58585/120.97706), which is the stretch the
      // Intramuros Administration's presidential bas-relief gallery runs
      // along. The previous value was clearly wrong — well west of the
      // walls, out in the reclaimed land by Bonifacio Drive.
      coordinates: const LatLng(14.5864, 120.9762),
    ),
    _RawSite(
      id: 'plaza-de-armas',
      budgetRange: const BudgetRange(min: 50, max: 75),
      name: 'Plaza de Armas',
      category: 'Parks',
      type: 'Historic plaza',
      note: 'Open space inside Fort Santiago',
      access: 'Fort entry',
      photo: 'assets/intravel/assets/home/fort-santiago.jpg',
      area: 'Inside Fort Santiago',
      history:
          "Plaza de Armas is the central open space within Fort Santiago, historically associated with the citadel's military layout and now part of the visitor route.",
      highlights: [
        'Fort Santiago open space',
        'Views of the citadel walls',
        'Rizal and fort heritage route',
      ],
      visitNote:
          'Fort Santiago admission and operating rules apply to this location.',
      // OSM way 331784448 "Plaza de Armas" (wikidata Q14146227), inside
      // Fort Santiago: 14.59454, 120.97009.
      coordinates: const LatLng(14.5945, 120.9701),
      relatedPlaceIds: ['fort-santiago', 'museo-ni-rizal'],
    ),
    _RawSite(
      id: 'plaza-moriones',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Plaza Moriones',
      category: 'Parks',
      type: 'Open space',
      note: 'Historic public plaza',
      access: 'Free exterior',
      photo: 'assets/intravel/assets/home/plaza-roma.jpg',
      area: 'Northern Intramuros',
      history:
          'Plaza Moriones is a historic plaza near Fort Santiago in the northern part of Intramuros.',
      highlights: [
        'Fort Santiago approach',
        'Historic public-square setting',
        'Nearby restaurants and visitor services',
      ],
      visitNote:
          'This is an exterior public space. Exercise normal care around vehicles and pedestrian crossings.',
      // OSM way 85932692 "Plaza Moriones" (wikidata Q89995646):
      // 14.59327, 120.97110.
      coordinates: const LatLng(14.5933, 120.9711),
      relatedPlaceIds: ['fort-santiago', 'fort-santiago-riverwalk'],
    ),
    _RawSite(
      id: 'baluarte-de-santa-barbara',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluarte de Santa Barbara',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Historic defensive wall',
      access: 'Historic exterior',
      photo: 'http://photos.wikimapia.org/p/00/05/75/67/01_1280.jpg',
      area: 'Northern waterfront wall',
      history:
          'Baluarte de Santa Barbara is a historic bastion in the northern waterfront sector of Intramuros, part of the defensive line near Fort Santiago.',
      highlights: [
        'Northern defensive walls',
        'Fort Santiago vicinity',
        'Historic waterfront context',
      ],
      visitNote:
          'View from designated exterior routes; access can be restricted during repairs or site operations.',
      // Verified against the Historical Marker Database (hmdb.org) marker
      // for Baluarte de Santa Barbara, which places it inside Fort
      // Santiago itself (14° 35.702' N, 120° 58.177' E) rather than the
      // previous coordinate, which was roughly 350m away.
      // OSM way 828670515 "Baluarte de Santa Barbara": 14.59504,
      // 120.96934.
      coordinates: const LatLng(14.5950, 120.9693),
      relatedPlaceIds: ['fort-santiago'],
    ),
    _RawSite(
      id: 'colegio-de-san-juan-de-letran',
      budgetRange: const BudgetRange(min: 0, max: 20),
      name: 'Colegio de San Juan de Letran',
      category: 'Schools',
      type: 'School',
      note: 'Oldest existing college in the Philippines',
      access: 'Private campus',
      photo:
          'https://upload.wikimedia.org/wikipedia/commons/2/2e/Colegio_de_San_Juan_de_Letran%2C_2018_%2801%29.jpg',
      area: 'Muralla Street, Intramuros',
      history:
          'Founded in 1620 as an orphanage school by retired Spanish officer Juan Geronimo Guerrero, Colegio de San Juan de Letran merged with a second Dominican-run school in 1649 to form the college that stands today. It is recognized as the oldest existing college in the Philippines and one of only two original schools still operating within the walls of Intramuros.',
      highlights: [
        'Historic Dominican-run Catholic college campus',
        'One of two schools still operating within the original walls',
        'Basic education and college programs on the same historic site',
      ],
      visitNote:
          'This is an active private school campus, not a public tourist attraction — access is generally limited to students, staff, and visitors with official business.',
      // OSM relation 14033842 "Colegio de San Juan de Letran" (wikidata
      // Q1108074), Muralla St: 14.59323, 120.97655.
      coordinates: const LatLng(14.5932, 120.9766),
      relatedPlaceIds: ['baluarte-de-santa-barbara', 'fort-santiago'],
    ),
    _RawSite(
      id: 'mapua-university-intramuros',
      budgetRange: const BudgetRange(min: 0, max: 20),
      name: 'Mapúa University (Intramuros Campus)',
      category: 'Schools',
      type: 'School',
      note: "Manila's premier engineering university",
      access: 'Private campus',
      photo:
          'https://upload.wikimedia.org/wikipedia/commons/c/ca/Mapua-intramuros.jpg',
      area: 'Muralla Street, Intramuros',
      history:
          "Mapúa University was founded in 1925 by Tomas Mapúa, the first registered Filipino architect. The Mapúa family acquired land within Intramuros in 1951, and the Intramuros campus opened in 1956, becoming the university's main site by 1973. It remains one of the country's leading engineering and technology schools.",
      highlights: [
        "The Philippines' leading engineering and architecture school",
        'Historic administration building facade on Muralla Street',
        'Anchors the modern University Belt presence within Intramuros',
      ],
      visitNote:
          'This is an active university campus. General visitors should expect the same access restrictions as any operating school.',
      // OSM way 27790819 "Mapúa University" (wikidata Q3268248), 658
      // Muralla St: 14.59050, 120.97809.
      coordinates: const LatLng(14.5905, 120.9781),
      relatedPlaceIds: ['colegio-de-san-juan-de-letran'],
    ),
    _RawSite(
      id: 'pamantasan-ng-lungsod-ng-maynila',
      budgetRange: const BudgetRange(min: 0, max: 20),
      name: 'Pamantasan ng Lungsod ng Maynila',
      category: 'Schools',
      type: 'School',
      note: 'Public university of the City of Manila',
      access: 'Public campus',
      photo:
          'https://upload.wikimedia.org/wikipedia/commons/4/4e/Pamantasan_ng_Lungsod_ng_Maynila.JPG',
      area: 'General Luna Street corner Muralla Street, Intramuros',
      history:
          "Pamantasan ng Lungsod ng Maynila, also known as the University of the City of Manila, was established on 19 June 1965 and opened its doors on 17 July 1967 to 556 scholars drawn from the top ten percent of Manila's public high school graduates. It is the first and only university chartered and funded directly by a Philippine city government.",
      highlights: [
        'The only city-government-chartered university in the Philippines',
        'Historic Gusaling Katipunan and Gusaling Don Pepe Atienza buildings',
        'Scholarship-driven admissions rooted in Manila public high schools',
      ],
      visitNote:
          'This is an active public university campus within the walls; general tourist access is limited to the exterior and grounds.',
      // OSM way 27275574 "Pamantasan ng Lungsod ng Maynila" (wikidata
      // Q2032807), General Luna cor. Muralla: 14.58686, 120.97644.
      coordinates: const LatLng(14.5869, 120.9764),
      relatedPlaceIds: ['colegio-de-san-juan-de-letran', 'plaza-roma'],
    ),
    _RawSite(
      id: 'revellin-de-puerta-real-de-bagumbayan',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Revellin de Puerta Real de Bagumbayan',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Historic defensive work',
      access: 'Historic exterior',
      photo:
          'https://commons.wikimedia.org/wiki/Special:FilePath/04086jfIntramuros%20Manila%20Heritage%20Landmarksfvf%2031.jpg?width=800',
      area: 'Puerta Real',
      history:
          'This ravelin is the outer defence of Puerta Real, the Royal Gate that historically faced Bagumbayan. It helped shield the gate from direct attack.',
      highlights: [
        'Puerta Real defensive approach',
        'Ravelin and moat context',
        'Nearby garden setting',
      ],
      visitNote:
          'Outdoor access and event use can change. Confirm on-site conditions before travelling.',
      // Verified against a camera-geotagged Wikimedia Commons photo taken
      // beside this ravelin (same photo set as the corrected Baluarte de
      // San Diego Gardens entry): 14°35'8"N 120°58'38"E -- previous value
      // was off by roughly 300m in longitude, placing it much further
      // west than the real site.
      coordinates: const LatLng(14.5856, 120.9772),
      relatedPlaceIds: ['puerta-real-gardens', 'baluarte-de-san-diego'],
    ),
    _RawSite(
      id: 'baluarillo-de-san-juan',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluarillo de San Juan',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Small bastion on the seafront wall',
      access: 'Free',
      photo:
          'https://intramuros.gov.ph/wp-content/uploads/2022/09/San-Andres-2-1024x559.png',
      area: 'Seafront Complex, southwestern wall',
      history:
          "Baluarillo de San Juan is a small bastion on the southwestern seafront wall of Intramuros, part of the Seafront Complex that defended the city's coastal edge.",
      highlights: [
        'Small bastion on the seafront wall',
        'Part of the Seafront Complex fortifications',
        'Views along the southwestern coastal defences',
      ],
      visitNote:
          'This is a heritage exterior. Observe posted barriers and stay on authorised paths.',
      // Not individually mapped in OSM. Placed on the southwestern curtain
      // wall between its two documented neighbours — Puerta de Santa Lucia
      // (OSM way 331675588, 14.58850/120.97372) to the north and
      // Baluartillo de San Jose (OSM way 331675589, 14.58675/120.97469) to
      // the south — which is where the Intramuros Administration's
      // Seafront Complex places it. Approximate to within a few tens of
      // metres, but on the wall line rather than the previous value, which
      // fell outside the walls in the reclaimed land to the west.
      coordinates: const LatLng(14.5878, 120.9741),
      relatedPlaceIds: [
        'baluartillo-de-san-jose',
        'reducto-de-san-pedro',
        'baluarte-de-san-diego',
      ],
    ),
    _RawSite(
      id: 'baluartillo-de-san-jose',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluartillo de San Jose',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Small defensive work on the seafront',
      access: 'Free',
      photo:
          'https://intramuros.gov.ph/wp-content/uploads/2022/09/San-Andres-2-1024x559.png',
      area: 'Seafront Complex, southwestern wall',
      history:
          'Baluartillo de San Jose is a small defensive work within the Seafront Complex of Intramuros, forming part of the interconnected coastal fortifications south of the walled city.',
      highlights: [
        'Interconnected coastal defence structure',
        'Part of the Seafront Complex network',
        'Historic stonework and wall remnants',
      ],
      visitNote:
          'Exterior access only. Respect barriers and conservation work in the area.',
      // OSM way 331675589 "Baluartillo de San Jose", Victoria St:
      // 14.58675, 120.97469. The previous value fell outside the walls, in
      // the reclaimed land west of the seafront wall.
      coordinates: const LatLng(14.5867, 120.9747),
      relatedPlaceIds: [
        'baluarillo-de-san-juan',
        'reducto-de-san-pedro',
        'baluarte-de-san-diego',
      ],
    ),
    _RawSite(
      id: 'reducto-de-san-pedro',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Reducto de San Pedro',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Compact redoubt on southwestern wall',
      access: 'Free',
      photo:
          'https://intramuros.gov.ph/wp-content/uploads/2022/09/Reducto-Javier-1.png',
      area: 'Southwestern wall near Santa Lucia',
      history:
          'Reducto de San Pedro is a compact defensive redoubt on the southwestern wall of Intramuros. It served as an ammunition storage point during the Spanish colonial era and is now a heritage ruin.',
      highlights: [
        'Former ammunition storage point',
        'Compact redoubt defensive architecture',
        'Heritage ruin on the southwestern wall',
      ],
      visitNote:
          'This is a heritage ruin. Do not climb or enter unsafe structures; observe from designated paths.',
      // OSM way 89572174 "Reducto de San Pedro" (defensive_works=redoubt):
      // 14.58654, 120.97436. Previous value was outside the walls.
      coordinates: const LatLng(14.5865, 120.9744),
      relatedPlaceIds: [
        'baluarillo-de-san-juan',
        'baluartillo-de-san-jose',
        'baluarte-de-san-diego',
      ],
    ),
    _RawSite(
      id: 'puerta-del-parian-revellin-del-parian',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Puerta del Parian & Revellin del Parian',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Original 1593 gate and forward defense',
      access: 'Free',
      photo: 'assets/intravel/assets/home/puerta-del-parian.jpg',
      area: 'Eastern wall of Intramuros',
      history:
          'Puerta del Parian is one of the original gates of Intramuros, built in 1593 and named after the Parian market of Chinese merchants. The attached Revellin del Parian provided forward defense. The gate was restored between 1967 and 1982.',
      highlights: [
        'One of the original 1593 gates of Intramuros',
        "Named after the Chinese merchants' Parian market",
        'Restored between 1967 and 1982',
      ],
      visitNote:
          'Free exterior access. The gate area may be affected by nearby road traffic; exercise care.',
      // Verified against a camera-geotagged Wikimedia Commons photo taken
      // at this gate: 14°35'32"N 120°58'41"E.
      coordinates: const LatLng(14.5922, 120.9781),
      relatedPlaceIds: [
        'asean-gardens',
        'galleria-de-los-presidentes',
        'fort-santiago',
      ],
    ),
    _RawSite(
      id: 'puerta-isabel-ii',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Puerta Isabel II',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Last gate built in Intramuros (1861)',
      access: 'Free',
      photo: 'assets/intravel/assets/home/puerta-isabel-ii.jpg',
      area: 'Northern wall facing Binondo',
      history:
          'Puerta Isabel II was the last gate built in Intramuros, opened in 1861 to relieve heavy pedestrian traffic outside the Parian Gate heading toward the Bridge of Spain and Binondo. A statue of Queen Isabel II stands in front. Damaged in 1945, it was restored in 1966.',
      highlights: [
        'Last gate constructed in Intramuros (1861)',
        'Statue of Queen Isabel II at the entrance',
        'Restored in 1966 after WWII damage',
      ],
      visitNote:
          'Free exterior access. Located near Colegio de San Juan de Letran on the northern wall.',
      // OSM node 10243714050 "Puerta de Isabel II" (operator: Intramuros
      // Administration): 14.59415, 120.97625.
      coordinates: const LatLng(14.5941, 120.9763),
      relatedPlaceIds: [
        'colegio-de-san-juan-de-letran',
        'fort-santiago',
        'plaza-moriones',
      ],
    ),
    _RawSite(
      id: 'foro-de-intramuros',
      budgetRange: const BudgetRange(min: 30, max: 100),
      name: 'Foro de Intramuros',
      category: 'Landmarks',
      type: 'Cultural venue',
      note: 'Event venue for performances and conferences',
      access: 'Event-dependent',
      photo: 'assets/intravel/assets/home/palacio.jpg',
      area: 'Central Intramuros',
      history:
          'Foro de Intramuros is a cultural event venue within the walled city that hosts performances, conferences, and community events celebrating Philippine heritage.',
      highlights: [
        'Cultural performance and conference venue',
        'Hosts community heritage events',
        'Located in the heart of the walled city',
      ],
      visitNote:
          'Access depends on scheduled events. Check current programming before visiting.',
      coordinates: const LatLng(14.5895, 120.9755),
      relatedPlaceIds: [
        'plaza-san-luis-complex',
        'casa-manila-museum',
        'san-agustin-church',
      ],
    ),
    _RawSite(
      id: 'fr-george-willman-museum',
      budgetRange: const BudgetRange(min: 50, max: 100),
      name: 'Fr. George Willman Museum',
      category: 'Landmarks',
      type: 'Museum',
      note: 'Commemorates Jesuit restorer of Intramuros',
      access: 'Donation',
      photo: 'assets/intravel/assets/home/fr-george-willman-museum.jpg',
      area: 'General Luna Street, near San Agustin',
      history:
          'The Fr. George J. Willman, S.J. Museum commemorates the Austrian-born Jesuit priest who dedicated decades to the restoration of Intramuros and the preservation of San Agustin Church after World War II.',
      highlights: [
        'Commemorates the restorer of post-war Intramuros',
        'Located near San Agustin Church',
        'Tells the story of heritage preservation efforts',
      ],
      visitNote:
          'Suggested donation of PHP 50. Confirm operating hours before visiting.',
      coordinates: const LatLng(14.5892, 120.9748),
      relatedPlaceIds: [
        'san-agustin-church',
        'san-agustin-museum',
        'casa-manila-museum',
      ],
    ),
    _RawSite(
      id: 'ncca-gallery',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'NCCA Gallery',
      category: 'Landmarks',
      type: 'Gallery',
      note: 'Exhibition space for emerging Filipino artists',
      access: 'Free',
      photo: 'assets/intravel/assets/home/ncca-gallery.jpg',
      area: '633 General Luna Street',
      history:
          'The NCCA Gallery at the National Commission for Culture and the Arts building provides exhibition space for young and emerging Filipino artists. Since 2009, it has hosted rotating exhibits promoting creative exploration.',
      highlights: [
        'Rotating exhibits by emerging Filipino artists',
        'Free admission to exhibitions',
        'Part of the NCCA cultural programme since 2009',
      ],
      visitNote:
          'Free admission. Check current exhibit schedule with the NCCA before visiting.',
      // OSM way 421439722 "National Commission for Culture and the Arts",
      // whose building at 633 General Luna St houses the gallery:
      // 14.58829, 120.97593.
      coordinates: const LatLng(14.5883, 120.9759),
      relatedPlaceIds: [
        'palacio-del-gobernador',
        'ayuntamiento-de-manila',
        'plaza-roma',
      ],
    ),
    _RawSite(
      id: 'bagumbayan-light-and-sound-museum',
      budgetRange: const BudgetRange(min: 100, max: 180),
      name: 'Bagumbayan Light and Sound Museum',
      category: 'Landmarks',
      type: 'Museum',
      note: 'Immersive audio-visual history experience',
      access: 'Guided tour',
      photo: 'assets/intravel/assets/home/fort-santiago.jpg',
      area: 'Victoria Street corner Santa Lucia Street',
      history:
          "The Intramuros and Rizal's Bagumbayan Light and Sound Museum brings Philippine history and the life of Jose Rizal to life through guided audio-visual presentations, narrated journeys, and immersive light shows.",
      highlights: [
        'Immersive light and sound historical presentations',
        'Guided narrated journey through Philippine history',
        'Brings the story of Jose Rizal to life',
      ],
      visitNote:
          'Approximately PHP 150 per person for guided tour. Confirm schedule and availability.',
      // OSM way 828366030 "Bagumbayan Light and Sound Museum", Santa Lucia
      // St: 14.58662, 120.97535.
      coordinates: const LatLng(14.5866, 120.9754),
      relatedPlaceIds: [
        'fort-santiago',
        'galleria-de-los-presidentes',
        'reducto-de-san-pedro',
      ],
    ),
    _RawSite(
      id: 'chamber-of-commerce',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Chamber of Commerce',
      category: 'Landmarks',
      type: 'Historic site',
      note: 'Recalls the mercantile role of Intramuros',
      access: 'Free',
      photo: 'assets/intravel/assets/home/chamber-of-commerce.jpg',
      area: 'Central Intramuros',
      history:
          'The historic Chamber of Commerce site in Intramuros recalls the mercantile role of the walled city during the Spanish and American colonial periods.',
      highlights: [
        'Recalls the commercial history of Intramuros',
        'Historic mercantile district context',
        'Spanish and American colonial period significance',
      ],
      visitNote:
          'Free exterior viewing. The site is primarily a historic landmark.',
      // OSM node 7454084487 / way 34363634 "Chamber of Commerce of the
      // Philippine Islands": 14.59467, 120.97616. This genuinely sits on
      // the riverside strip just outside the northern wall, between Muralla
      // Street and the Pasig — still Intramuros district, not inside the
      // wall line.
      coordinates: const LatLng(14.5947, 120.9762),
      relatedPlaceIds: [
        'ayuntamiento-de-manila',
        'plaza-roma',
        'palacio-del-gobernador',
      ],
    ),
    _RawSite(
      id: 'aduana-intendencia',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Aduana (Intendencia)',
      category: 'Landmarks',
      type: 'Historic site',
      note: 'Spanish colonial customs house',
      access: 'Free',
      photo: 'assets/intravel/assets/home/aduana-intendencia.jpg',
      area: 'Plaza España, Soriano Avenue corner Muralla Street',
      history:
          'The Aduana Building, also known as the Intendencia, was a Spanish colonial customs house in Intramuros. Located at Plaza España facing Soriano Avenue and Muralla Street, it housed government offices through multiple administrations.',
      highlights: [
        'Former Spanish colonial customs house',
        'Located at historic Plaza España',
        'Housed government offices across multiple eras',
      ],
      visitNote:
          'Free exterior viewing. Interior access is not guaranteed; confirm before visiting.',
      // OSM way 89184408 "National Archives of the Philippines", the
      // adaptive reuse of the Aduana/Intendencia building on Magallanes
      // Drive: 14.59400, 120.97460.
      coordinates: const LatLng(14.5940, 120.9746),
      relatedPlaceIds: [
        'plaza-espana',
        'ayuntamiento-de-manila',
        'puerta-isabel-ii',
      ],
    ),
    _RawSite(
      id: 'plaza-de-santo-tomas',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Plaza de Santo Tomas',
      category: 'Parks',
      type: 'Historic plaza',
      note: 'Historic open space on Santo Tomas Street',
      access: 'Free',
      photo: 'assets/intravel/assets/home/plaza-de-santo-tomas.jpg',
      area: 'Santo Tomas Street, Intramuros',
      history:
          'Plaza de Santo Tomas is a historic open space in Intramuros on Santo Tomas Street, named for Saint Thomas. The plaza forms part of the network of public open spaces that structured the urban plan of the walled city.',
      highlights: [
        'Historic open space named for Saint Thomas',
        'Part of the planned urban layout of Intramuros',
        'Quiet rest stop between heritage landmarks',
      ],
      visitNote:
          'Free public open space. Open at all times; exercise normal pedestrian care.',
      coordinates: const LatLng(14.5929, 120.9745),
      relatedPlaceIds: [
        'plaza-roma',
        'manila-cathedral',
        'ayuntamiento-de-manila',
      ],
    ),
    _RawSite(
      id: 'plaza-espana',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Plaza España',
      category: 'Parks',
      type: 'Public square',
      note: 'Triangular plaza with Philip II monument',
      access: 'Free',
      photo: 'assets/intravel/assets/home/plaza-roma.jpg',
      area: 'Soriano Avenue corner Solana and Muralla Streets',
      history:
          'Plaza de España is a triangular public square in Intramuros formed by the intersection of Andres Soriano Avenue, Solana Street, and Muralla Street. It features a monument to King Philip II of Spain, after whom the Philippines was named.',
      highlights: [
        'Monument to King Philip II of Spain',
        'Triangular plaza at three-street intersection',
        'Historic public square in the walled city',
      ],
      visitNote:
          'Free public open space. Open at all times; be mindful of surrounding traffic.',
      // OSM way 59293274 "Plaza España" (wikidata Q25221977): 14.59358,
      // 120.97454.
      coordinates: const LatLng(14.5936, 120.9745),
      relatedPlaceIds: [
        'aduana-intendencia',
        'puerta-isabel-ii',
        'colegio-de-san-juan-de-letran',
      ],
    ),
    _RawSite(
      id: 'manila-high-school',
      budgetRange: const BudgetRange(min: 0, max: 20),
      name: 'Manila High School',
      category: 'Schools',
      type: 'Public school',
      note: 'Public secondary school in Intramuros',
      access: 'Free',
      photo: 'assets/intravel/assets/home/manila-high-school.jpg',
      area: 'Intramuros, Manila',
      history:
          'Manila High School is a public secondary school located within the walled city of Intramuros. It serves the local student community and is part of the educational institutions situated within the historic district.',
      highlights: [
        'Public secondary school in the walled city',
        'Serves the local Intramuros student community',
        'Part of the historic district educational network',
      ],
      visitNote:
          'Public school campus. Visitor access requires coordination with school administration.',
      // Verified against a camera-geotagged Wikimedia Commons photo taken
      // at Manila High School (14°35'21"N 120°58'27"E) -- previous value
      // was off by roughly 300m.
      // OSM way 83591315 "Manila High School" (wikidata Q25211962),
      // Muralla cor. Victoria: 14.58902, 120.97842. The previous value was
      // ~455m west, over by San Agustin instead of on the eastern wall.
      coordinates: const LatLng(14.5890, 120.9784),
      relatedPlaceIds: [
        'colegio-de-san-juan-de-letran',
        'puerta-isabel-ii',
        'fort-santiago',
      ],
    ),
    _RawSite(
      id: 'lyceum-of-the-philippines-university',
      budgetRange: const BudgetRange(min: 0, max: 20),
      name: 'Lyceum of the Philippines University',
      category: 'Schools',
      type: 'University',
      note: 'Tourism and hospitality university (1952)',
      access: 'Free',
      photo: 'assets/intravel/assets/home/lyceum-of-the-philippines.jpg',
      area: 'Muralla Street, Intramuros',
      history:
          'Lyceum of the Philippines University (LPU) is a private university in Intramuros established in 1952 by Dr. Jose P. Laurel. It is a member of the Intramuros Consortium and is known for its tourism and hospitality programs.',
      highlights: [
        'Established in 1952 by Dr. Jose P. Laurel',
        'Known for tourism and hospitality programs',
        'Member of the Intramuros Consortium',
      ],
      visitNote:
          'University campus. Visitor access to campus grounds may require coordination.',
      // OSM relation 8602738 "Lyceum of the Philippines University"
      // (wikidata Q3547527): 14.59154, 120.97783.
      coordinates: const LatLng(14.5915, 120.9778),
      relatedPlaceIds: [
        'mapua-university-intramuros',
        'pamantasan-ng-lungsod-ng-maynila',
        'bahay-tsinoy',
      ],
    ),
    // ─── Cafe sites (addendum spec 3 Section 1.1, 2.1): placeholder data
    // for the new "Cafe (WiFi & Sockets)" filter, giving the toggle and
    // map pin filtering something to display. Coordinates are realistic
    // points within Intramuros; hasWifi/hasSockets back the pin-popup
    // amenity indicators (addendum spec 3 Section 2.2).
    _RawSite(
      id: 'barbara-s-cafe',
      budgetRange: const BudgetRange(min: 150, max: 400),
      name: "Barbara's Heritage Cafe",
      category: 'Cafe',
      type: 'Cafe',
      note: 'Colonial-style cafe with WiFi and workspace seating',
      access: 'Free entry, pay per order',
      photo: 'assets/intravel/assets/home/plaza-roma.jpg',
      area: 'Plaza San Luis Complex, Intramuros',
      history:
          'A colonial-themed cafe within the Plaza San Luis Complex, popular with visitors and remote workers alike for its garden seating and reliable WiFi.',
      highlights: [
        'Garden and indoor seating',
        'Free WiFi for customers',
        'Power outlets at most tables',
      ],
      visitNote:
          'Placeholder site data. A relaxed spot to rest and recharge devices while exploring Intramuros.',
      coordinates: const LatLng(14.5896, 120.9739),
      relatedPlaceIds: ['san-agustin-church', 'casa-manila-museum'],
      hasWifi: true,
      hasSockets: true,
    ),
    _RawSite(
      id: 'cafe-de-muralla',
      budgetRange: const BudgetRange(min: 100, max: 300),
      name: 'Cafe de Muralla',
      category: 'Cafe',
      type: 'Cafe',
      note: 'Cozy cafe along the old city walls, WiFi available',
      access: 'Free entry, pay per order',
      photo: 'assets/intravel/assets/home/plaza-roma.jpg',
      area: 'Muralla Street, Intramuros',
      history:
          'A small cafe tucked along Muralla Street, near the old city walls, serving coffee and light meals to tourists and students from nearby schools.',
      highlights: [
        'Seating along the historic city wall',
        'Free WiFi for customers',
        'No dedicated power outlets',
      ],
      visitNote:
          'Placeholder site data. Good for a quick coffee break between walking tours.',
      coordinates: const LatLng(14.5911, 120.9758),
      relatedPlaceIds: ['manila-cathedral', 'plaza-espana'],
      hasWifi: true,
      hasSockets: false,
    ),
    _RawSite(
      id: 'fort-brew-coffee',
      budgetRange: const BudgetRange(min: 120, max: 350),
      name: 'Fort Brew Coffee',
      category: 'Cafe',
      type: 'Cafe',
      note: 'Coffee shop near Fort Santiago with laptop-friendly seating',
      access: 'Free entry, pay per order',
      photo: 'assets/intravel/assets/home/fort-santiago.jpg',
      area: 'Near Fort Santiago, Intramuros',
      history:
          'A modern coffee shop just outside Fort Santiago, catering to tourists and remote workers with dedicated workspace seating.',
      highlights: [
        'Laptop-friendly indoor seating',
        'Free WiFi for customers',
        'Power outlets at every table',
      ],
      visitNote:
          'Placeholder site data. A convenient stop for visitors needing WiFi and charging before or after touring Fort Santiago.',
      coordinates: const LatLng(14.5935, 120.9712),
      relatedPlaceIds: ['fort-santiago', 'museo-ni-rizal'],
      hasWifi: true,
      hasSockets: true,
    ),

    // ─── Locations dataset completion (improvement-batch spec Section 6) ─────
    // The eight entries below close the gap between this catalogue and
    // `docs/intramuros-app-spec-locations.md`, which lists 12 Fortifications
    // and 8 Parks where this file previously had 9 and 11 (the Parks surplus
    // is gardens/promenades the doc doesn't enumerate, which are kept).
    //
    // Every coordinate here is taken from OpenStreetMap (ODbL) rather than
    // estimated, with the source element cited inline. Two of the eight have
    // no OSM element and no published coordinate; those say so explicitly and
    // explain how their position was derived from mapped neighbours, rather
    // than presenting a guess as verified.
    //
    // Photos: none of these eight has a dedicated image in `assets/`, so each
    // either points at a real, checked Wikimedia Commons/Intramuros
    // Administration file or reuses the nearest existing in-repo photo of the
    // same wall section. Flagged per entry so it's obvious which are stand-ins
    // awaiting a proper photo.
    _RawSite(
      id: 'baluarte-plano-luneta-de-santa-isabel',
      budgetRange: const BudgetRange(min: 150, max: 400),
      name: 'Baluarte Plano Luneta de Santa Isabel',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Flat bastion on Santa Lucia Street; now a food hall',
      access: 'Free to enter, pay per order at the food stalls',
      // Stand-in photo: nearest bastion on the same seafront wall.
      photo: 'assets/intravel/assets/home/baluarte-de-san-diego.jpg',
      area: 'Santa Lucia Street, western wall',
      history:
          'Named after St Elizabeth, this "plano" or flat bastion sits on the western wall near Puerta de Santa Lucia. Unlike the pointed ace-of-spades bastions elsewhere on the walls, its platform is level, which is what the name records. In recent years the Intramuros Administration has leased the grounds for public events, including the Department of Tourism\'s Philippine Eatsperience food village, so visitors today usually find it in use as a dining and events space rather than as a bare ruin.',
      highlights: [
        'Level "plano" bastion platform, unusual among the walls',
        'Adaptive reuse as an events and dining venue',
        'Steps from Puerta de Santa Lucia on the western wall',
      ],
      visitNote:
          'What is open here depends on which event or concessionaire is running the grounds, so opening hours and prices shift. Check the Intramuros Administration listings before travelling.',
      // OSM way 331675587 "Baluarte Plano de Sta. Isabela"
      // (defensive_works=bastion): 14.58950, 120.97292.
      coordinates: const LatLng(14.5895, 120.9729),
      relatedPlaceIds: [
        'baluarillo-de-san-juan',
        'baluartillo-de-san-eugenio',
        'museo-de-intramuros',
      ],
    ),
    _RawSite(
      id: 'baluartillo-de-san-eugenio',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluartillo de San Eugenio',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Small bastion and archaeological site on the western wall',
      access: 'Free',
      // Stand-in photo: nearest bastion on the same seafront wall.
      photo: 'assets/intravel/assets/home/baluarte-de-san-diego.jpg',
      area: 'Western wall, between Santa Isabel and Santa Lucia',
      history:
          'A "baluartillo" is a small bastion, and this one — named after St Eugene — is one of the minor works punctuating the western wall between Baluarte Plano de Santa Isabel and Puerta de Santa Lucia. Much of it survives as an archaeological site rather than a standing structure, so what is visible is excavated stonework and foundations rather than a restored bastion.',
      highlights: [
        'Archaeological site rather than a restored structure',
        'One of the minor works on the western seafront wall',
        'Excavated Spanish-era foundations and stonework',
      ],
      visitNote:
          'An active archaeological area. Stay on the marked paths, do not climb the excavated stonework, and expect parts to be fenced off during conservation work.',
      // Not mapped in OSM and no published coordinate found, so this is a
      // derived position rather than a verified one: placed on the western
      // curtain wall between the two mapped works the Intramuros
      // Administration's own fortifications list puts it between — Baluarte
      // Plano de Santa Isabel (OSM way 331675587, 14.58950/120.97292) and
      // Puerta de Santa Lucia (OSM way 331675588, 14.58850/120.97372).
      coordinates: const LatLng(14.5890, 120.9733),
      relatedPlaceIds: [
        'baluarte-plano-luneta-de-santa-isabel',
        'baluarillo-de-san-juan',
        'reducto-de-san-pedro',
      ],
    ),
    _RawSite(
      id: 'baluarte-de-san-andres',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluarte de San Andres',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Bastion guarding the southeastern corner of the walls',
      access: 'Free',
      photo:
          'https://intramuros.gov.ph/wp-content/uploads/2022/09/San-Andres-2-1024x559.png',
      area: 'Muralla Street, southeastern wall',
      history:
          'Built in 1603 to cover Puerta Real and the southeastern corner of Intramuros, this bastion is named after St Andrew, who was proclaimed patron of Manila after the city withstood the Chinese corsair Limahong\'s attack in 1574. It anchors the angle where the southern wall turns north toward the Parian side.',
      highlights: [
        'Built in 1603 to protect Puerta Real',
        'Named for St Andrew, patron of Manila after the 1574 attack',
        'Anchors the southeastern angle of the walls',
      ],
      visitNote:
          'Heritage exterior on a busy stretch of Muralla Street. Watch for traffic on the approach and observe any posted barriers.',
      // OSM way 331628853 "Baluarte De San Andres" (wikidata Q48817289,
      // defensive_works=bastion), Muralla Street: 14.58707, 120.97863.
      coordinates: const LatLng(14.5871, 120.9786),
      relatedPlaceIds: [
        'revellin-de-puerta-real-de-bagumbayan',
        'revellin-de-recoletos',
        'manila-high-school',
      ],
    ),
    _RawSite(
      id: 'revellin-de-recoletos',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Revellin de Recoletos',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Outer defence beside the old Recollect church; now Escuela Taller',
      access: 'Free exterior; interior access depends on the school',
      photo:
          'https://commons.wikimedia.org/wiki/Special:FilePath/03679jfIntramuros%20Gates%20Baluarte%20Recoletos%20Schools%20Streets%20Landmarksfvf%2037.jpg?width=800',
      area: 'Victoria Street, eastern wall',
      history:
          'A ravelin — a detached, wedge-shaped outwork sited in front of the wall — built to shield the gate beside the church and convent of the Augustinian Recollects. The structure now houses Escuela Taller de Filipinas, a school that trains young Filipinos in traditional building trades and uses the fortification itself as a working conservation classroom.',
      highlights: [
        'Ravelin outwork protecting the Recollects\' gate',
        'Home of Escuela Taller\'s heritage-conservation trade school',
        'Restored stonework used for hands-on craft training',
      ],
      visitNote:
          'The grounds are a working school. The exterior can be viewed freely, but visiting inside generally needs to be arranged with Escuela Taller in advance.',
      // OSM relation 2406221 "Revellín de Recoletos", Muralla Street:
      // 14.58859, 120.97951.
      coordinates: const LatLng(14.5886, 120.9795),
      relatedPlaceIds: [
        'baluarte-de-san-andres',
        'baluarte-de-dilao',
        'manila-high-school',
      ],
    ),
    _RawSite(
      id: 'baluarte-de-dilao',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluarte de Dilao',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Eastern-wall bastion facing the old Japanese quarter',
      access: 'Free',
      // Stand-in photo: adjacent structure on the same eastern wall.
      photo: 'assets/intravel/assets/home/puerta-del-parian.jpg',
      area: 'Muralla Street, eastern wall',
      history:
          'Fully Baluarte de San Francisco de Dilao, this bastion took its second name from Dilao, the Japanese enclave that stood east of the walls before its residents were resettled to Paco in the 1760s. The San Francisco part honours St Francis of Assisi, whose Franciscan churches — Our Lady of the Angels and the Venerable Orden Tercera — stood nearby inside the city.',
      highlights: [
        'Named for Dilao, the Japanese quarter east of the walls',
        'Also honours the Franciscan churches that stood nearby',
        'Restored bastion on the Muralla Street wall walk',
      ],
      visitNote:
          'One of the more accessible bastions on this stretch — OpenStreetMap records step-free access here — but conditions on the wall walk still vary, so check on arrival.',
      // OSM way 331628855 "Baluarte de San Francisco de Dilao"
      // (defensive_works=bastion, wheelchair=yes): 14.59039, 120.97910.
      coordinates: const LatLng(14.5904, 120.9791),
      relatedPlaceIds: [
        'revellin-de-recoletos',
        'puerta-del-parian-revellin-del-parian',
        'mapua-university-intramuros',
      ],
    ),
    _RawSite(
      id: 'baluarte-de-san-gabriel',
      budgetRange: const BudgetRange(min: 15, max: 40),
      name: 'Baluarte de San Gabriel',
      category: 'Fortifications',
      type: 'Fortification',
      note: 'Northern-wall bastion overlooking the Pasig',
      access: 'Free',
      // Stand-in photo: adjacent gate on the same northern wall.
      photo: 'assets/intravel/assets/home/puerta-isabel-ii.jpg',
      area: 'Anda Street, northern wall',
      history:
          'Named after the Archangel Gabriel, this bastion covers the northeastern turn of the walls where the eastern front meets the Pasig River frontage, a short walk from Puerta Isabel II. Its guns commanded the river approach and the wharves that made this the city\'s commercial edge.',
      highlights: [
        'Guards the northeastern turn of the walls',
        'Commands the Pasig River approach and old wharf side',
        'A short walk from Puerta Isabel II',
      ],
      visitNote:
          'Exterior viewing along Anda and Muralla streets. The riverside side of the wall is busier with traffic, so keep to the footpaths.',
      // OSM way 331628857 "Baluarte de San Gabriel"
      // (defensive_works=bastion), Anda Street: 14.59397, 120.97739.
      coordinates: const LatLng(14.5940, 120.9774),
      relatedPlaceIds: [
        'puerta-isabel-ii',
        'plaza-mexico',
        'colegio-de-san-juan-de-letran',
      ],
    ),
    _RawSite(
      id: 'plazuela-de-santa-isabel',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Plazuela de Santa Isabel',
      category: 'Parks',
      type: 'Pocket plaza',
      note: 'Small plaza holding the Memorare Manila 1945 monument',
      access: 'Free',
      // Stand-in photo: comparable pocket plaza inside the walls.
      photo: 'assets/intravel/assets/home/plaza-de-santo-tomas.jpg',
      area: 'General Luna corner Anda Street',
      history:
          'A small triangular plaza at the General Luna and Anda street corner, named for the Santa Isabel college that once stood in this quarter. It is best known now for Memorare Manila 1945, the marble monument unveiled in 1995 to the more than one hundred thousand civilians killed during the Battle of Manila, whose inscription is addressed to the "innocent victims" of that month of fighting.',
      highlights: [
        'Memorare Manila 1945 civilian-casualty monument',
        'Quiet shaded stop between Museo de Intramuros and Casa Manila',
        'Named for the old Santa Isabel college quarter',
      ],
      visitNote:
          'A memorial space as much as a plaza — it is a common site for wreath-laying every February, so expect ceremonies around the anniversary of the battle.',
      // OSM way 72518968 "Plazuela de Santa Isabel" (leisure=park):
      // 14.59047, 120.97446.
      coordinates: const LatLng(14.5905, 120.9745),
      relatedPlaceIds: [
        'museo-de-intramuros',
        'casa-manila-museum',
        'centro-de-turismo-intramuros',
      ],
    ),
    _RawSite(
      id: 'plaza-mexico',
      budgetRange: const BudgetRange(min: 15, max: 50),
      name: 'Plaza Mexico',
      category: 'Parks',
      type: 'Riverside plaza',
      note: 'Riverside square marking the Manila-Acapulco galleon trade',
      access: 'Free',
      // Stand-in photo: the adjoining Pasig riverside walk.
      photo: 'assets/intravel/assets/home/ia-pasig-esplanade.jpg',
      area: 'West end of Magallanes Drive, Pasig riverside',
      history:
          'A riverside square at the west end of Magallanes Drive, facing the Pasig on its northern side. It commemorates the two and a half centuries of the Manila-Acapulco galleon trade, which tied Intramuros directly to New Spain: the plaza and its counterpart Plaza Manila in Mexico City were dedicated as paired monuments to that shared history.',
      highlights: [
        'Commemorates the Manila-Acapulco galleon trade',
        'Paired with Plaza Manila in Mexico City',
        'Opens directly onto the Pasig River frontage',
      ],
      visitNote:
          'Open riverside space with little shade — best in the late afternoon. It connects to the Pasig River Esplanade walk along the same bank.',
      // OSM relation 18378284 "Plaza Mexico" (leisure=park): 14.59463,
      // 120.97470. Sits on the riverside strip north of the wall line, which
      // is where the real plaza is — still inside Intramuros district.
      coordinates: const LatLng(14.5946, 120.9747),
      relatedPlaceIds: [
        'pasig-river-esplanade',
        'puerta-isabel-ii',
        'aduana-intendencia',
      ],
    ),
  ];

  // ─── Curated reviews kept from the original native build ───────────────────
  // Only the flagship sites ship with hand-written reviews; every other site
  // gets an empty review list until real Google-sourced reviews are wired in.
  static final Map<String, List<Review>> _reviewsBySiteId = {
    'fort-santiago': [
      Review(
        id: 'r1',
        authorName: 'Maria Santos',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'A must-visit for history buffs! The grounds are well-maintained and the Rizal Shrine inside tells a powerful story. Best to visit early morning to avoid crowds.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r2',
        authorName: 'John Rivera',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Beautiful historical site with well-preserved architecture. The gardens are peaceful and perfect for photos. Entrance fee is very affordable.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r3',
        authorName: 'Angela Cruz',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the best-preserved Spanish colonial structures in the Philippines. Walking through the dungeons gives you chills. Very educational experience.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r4',
        authorName: 'Carlos Mendoza',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Great place to learn about Philippine history. The fort has a somber but beautiful atmosphere. Bring water as it can get hot during midday.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'san-agustin-church': [
      Review(
        id: 'r5',
        authorName: 'Patricia Lim',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Absolutely stunning baroque architecture. The ceiling paintings are breathtaking. A UNESCO Heritage site that truly deserves its status.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r6',
        authorName: 'Miguel Torres',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Beautiful church with rich history. The museum attached has interesting artifacts from the colonial era. Worth the entrance fee.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
    ],
    'manila-cathedral': [
      Review(
        id: 'r7',
        authorName: 'Rosa Dela Cruz',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Magnificent cathedral with beautiful stained glass and architecture. A peaceful place for worship and reflection. Free to enter.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r8',
        authorName: 'David Aquino',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the most beautiful churches in the Philippines. The pipe organ concerts are a unique experience. Highly recommend visiting during mass.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ],
    'casa-manila-museum': [
      Review(
        id: 'r9',
        authorName: 'Liza Ferrer',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Stepping into Casa Manila feels like time travel. The period furniture and courtyard are gorgeous, great for photos.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
    ],
    'museo-de-intramuros': [
      Review(
        id: 'r10',
        authorName: 'Noel Bautista',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Impressive ecclesiastical art collection housed in a beautifully reconstructed building. Well worth the admission.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'baluarte-de-san-diego': [
      Review(
        id: 'r11',
        authorName: 'Karen Villanueva',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The oldest stone fort in Manila! The circular ruins and garden make for a peaceful, photogenic visit.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r11b',
        authorName: 'Jonas Ecleo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'You can really see the layers of excavation here, the 1587 foundation stones are still visible under the newer masonry. Bring sunscreen, there is barely any shade in the open circular court.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Review(
        id: 'r11c',
        authorName: 'Precious Andrade',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'We had our prenup shoot here and the caretakers were so accommodating. The archaeological layout is genuinely interesting even if you are not into photography.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'museo-ni-rizal': [
      Review(
        id: 'r12a',
        authorName: 'Emerson Padilla',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Walking the same halls where Rizal spent his final nights before his execution is sobering. The recreated cell and his last letters on display stayed with me for days.',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r12b',
        authorName: 'Grace Tolentino',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Small but dense with history. Get an actual guide if you can, the plaques alone do not do the story justice. The bronze footsteps marking his final walk are a nice touch outside.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r12c',
        authorName: 'Miko Salazar',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Required visit for anyone who took up Rizal in school. Seeing his actual handwriting in the exhibited letters made the textbook version of him feel like a real person.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'fort-santiago-riverwalk': [
      Review(
        id: 'r13a',
        authorName: 'Denise Ocampo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Nice new addition to the fort. The riverside path along the old walls gives a totally different angle of Fort Santiago that most tourists never see.',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r13b',
        authorName: 'Ryan Custodio',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Pretty views of the Pasig but the smell from the river can be strong depending on the tide. Go around sunset when the breeze picks up.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r13c',
        authorName: 'Faith Barrientos',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Loved that this connects straight to the esplanade for a longer walk. Felt safe, well-lit in the early evening, and much less crowded than the main fort entrance.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'pasig-river-esplanade': [
      Review(
        id: 'r14a',
        authorName: 'Ariel Buenaventura',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Great for a morning jog before the heat kicks in. Wide enough for joggers and cyclists to share without bumping into each other.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r14b',
        authorName: 'Cherry Domingo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Underrated spot for river views of Manila. Bring your own water though, there are not a lot of vendors along this particular stretch yet.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r14c',
        authorName: 'Boyet Salonga',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'It is wild that this used to be an inaccessible industrial edge of the river. Now it is one of the calmest places in the whole walled city to just sit and watch the boats.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'plaza-san-luis-complex': [
      Review(
        id: 'r15a',
        authorName: 'Isabel Marasigan',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The cobblestone street and the row of colonial house facades make you forget you are in modern Manila for a minute. Perfect backdrop for photos.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r15b',
        authorName: 'Patrick Yumang',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Nice mix of cafes and souvenir shops built into the old house ground floors. A bit touristy in pricing but the ambiance makes up for it.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r15c',
        authorName: 'Sheena Aquino',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'This is the most Instagrammable corner of Intramuros in my opinion, and I have been to most of it. Go early before the tour groups arrive.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'centro-de-turismo-intramuros': [
      Review(
        id: 'r16a',
        authorName: 'Alvin Marcelo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Good first stop before exploring the rest of Intramuros. The exhibits give you enough context on the walled city that everything else you see afterward makes more sense.',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r16b',
        authorName: 'Josefina Reburiano',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            "The reconstructed San Ignacio Church setting is beautiful on its own, aside from the exhibits. Staff were happy to explain the church's destruction and rebuilding history in detail.",
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r16c',
        authorName: 'Diego Formoso',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Newer venue so it is not as crowded yet. Worth checking their cultural programme schedule before visiting since there are sometimes live demonstrations.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'baluarte-de-san-diego-gardens': [
      Review(
        id: 'r17a',
        authorName: 'Marites Concepcion',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Quiet garden right beside the old bastion, great place to rest after walking the fort ruins. Saw a small wedding shoot happening when we visited.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r17b',
        authorName: 'Wilfredo Tumbaga',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Nice enough but limited seating. Gets a bit muddy near the edges after rain so watch your footing.',
        publishedAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      Review(
        id: 'r17c',
        authorName: 'Aiza Villaflor',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The trees here are old and give real shade, unlike a lot of the more exposed plazas in Intramuros. Underrated picnic spot honestly.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'san-agustin-museum': [
      Review(
        id: 'r18a',
        authorName: 'Fr. Bautista Lim',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The vestments, silverware, and choir stalls collection here rival museums twice the size. The cloister itself is worth the ticket even without the exhibits.',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r18b',
        authorName: 'Cecilia Roa',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Combine your ticket with the church visit next door, they flow into each other naturally. The trompe-l\'oeil ceiling painting in the old refectory is the highlight for me.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r18c',
        authorName: 'Randall Ku',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Dim lighting in some galleries which protects the artifacts but makes photos hard without a good camera. Still one of the better-curated religious museums in Manila.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'bahay-tsinoy': [
      Review(
        id: 'r19a',
        authorName: 'Anthony Sy',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'As a Filipino-Chinese visitor, this is the first museum that actually told my family history properly. The section on the galleon trade era is especially well done.',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r19b',
        authorName: 'Melinda Tan-Uy',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Extremely thorough exhibits, budget at least two hours. The recreated ancestral house interior and the WWII memorial wall were both moving.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r19c',
        authorName: 'Oliver Gatchalian',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A bit out of the way compared to the other Intramuros stops but absolutely worth the extra walk. Wish more schools brought field trips here.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'destileria-limtuaco-museum': [
      Review(
        id: 'r20a',
        authorName: 'Renato Buenavista',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Fun detour from the usual church-and-fort circuit. Learning that a Filipino distillery has been running since the 1850s was news to me, and the tasting at the end sealed the deal.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r20b',
        authorName: 'Jasmine Del Pilar',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Small museum, more of a quick stop than a full activity. The Bino sourdipili liqueur samples were the best part honestly, not so much the exhibit itself.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r20c',
        authorName: 'Marco Ilagan',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Loved the family archive photos going back five generations. Book the guided tour and tasting combo if it is available, staff know a lot of trivia that is not on the placards.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'plaza-roma': [
      Review(
        id: 'r21a',
        authorName: 'Corazon Espiritu',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Best people-watching spot in Intramuros. The King Charles IV monument at the center and the cathedral backdrop make this the natural heart of the walled city.',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r21b',
        authorName: 'Bienvenido Cruz',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Lots of calesa drivers waiting around here, easy to just flag one down for a short loop of the district. Plaza itself is clean and well-maintained.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r21c',
        authorName: 'Nathalie Perez',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Free, open, and shaded enough to just sit for a while between museum visits. Great starting point if you are planning your walking route for the day.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'ayuntamiento-de-manila': [
      Review(
        id: 'r22a',
        authorName: 'Federico Santos-Reyes',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The reconstructed Cabildo facade is imposing even from the outside. Wish there was more public access inside, but as a photo subject beside Plaza Roma it delivers.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r22b',
        authorName: 'Luz Manalastas',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Government building so do not expect a tourist experience inside, but architecturally it fits right into the Plaza Roma ensemble with the cathedral.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r22c',
        authorName: 'Julius Ferrolino',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Mostly worth it for the historical context of colonial Manila governance. Not much to actually do here besides admire the exterior.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'palacio-del-gobernador': [
      Review(
        id: 'r23a',
        authorName: 'Rowena Batongbakal',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'More of a historical marker than an attraction since the original palace is long gone. Still, standing where the governor-generals once ruled the colony has some weight to it.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r23b',
        authorName: 'Danilo Quiambao',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Good vantage point toward the cathedral and Plaza Roma. Worth a quick stop if you are already walking that stretch of General Luna.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r23c',
        authorName: 'Yolanda Mercado',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Not much signage explaining what used to stand here, had to look it up myself afterward. Would benefit from a proper historical marker.',
        publishedAt: DateTime.now().subtract(const Duration(days: 49)),
      ),
    ],
    'puerta-real-gardens': [
      Review(
        id: 'r24a',
        authorName: 'Consolacion Uy',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Gorgeous event venue built right into a real 17th century gate. We attended a wedding reception here and the lighting on the old stone at night was stunning.',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r24b',
        authorName: 'Enrico Villaroman',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Nice garden to walk through even without an event happening. You can see where the old moat and ravelin used to be if you look at the ground contours.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r24c',
        authorName: 'Precy Naval',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the few Intramuros gates you can actually walk through and linger in rather than just photograph from outside. Highly recommend for golden hour shots.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'asean-gardens': [
      Review(
        id: 'r25a',
        authorName: 'Herminia Cabahug',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Quiet corner with the flags of all ASEAN countries planted along the walk. Nice unexpected find while walking the perimeter wall.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r25b',
        authorName: 'Armando Legaspi',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Small and easy to miss if you are not specifically looking for it near the old Revellin del Parian site. Nice for a five minute breather though.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r25c',
        authorName: 'Concepcion Rivas',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Symbolically nice given how much of Southeast Asian trade history passed through this port city. Peaceful, uncrowded, good for a slow morning walk.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'galleria-de-los-presidentes': [
      Review(
        id: 'r26a',
        authorName: 'Teodoro Mabini-Cruz',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Fun little detour, the bas-reliefs of every Philippine president in one row make for an easy history refresher. Great for kids on a school trip.',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r26b',
        authorName: 'Bernadette Sarmiento',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Compact pocket park, took maybe ten minutes to walk through. Close enough to the Santa Lucia gate area to combine into the same stop.',
        publishedAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      Review(
        id: 'r26c',
        authorName: 'Reynaldo Pascual',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Some of the reliefs could use cleaning but overall a nice free stop. Good shade from the surrounding trees during midday heat.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'plaza-de-armas': [
      Review(
        id: 'r27a',
        authorName: 'Salvador Nepomuceno',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The wide open parade ground inside the fort really gives you a sense of scale for how big Fort Santiago actually is. Great for the classic postcard shot of the main gate.',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r27b',
        authorName: 'Imelda Bautista-Ong',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Very exposed to the sun with little shade in the open plaza, go early or late afternoon. The view of the citadel walls from the center is worth it though.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r27c',
        authorName: 'Alfonso Trinidad',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Occasional cultural performances happen here on weekends, we got lucky and caught a folk dance group rehearsing. Ask the guards about the schedule.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'plaza-moriones': [
      Review(
        id: 'r28a',
        authorName: 'Norberto Villagracia',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Handy stop on the way to Fort Santiago, a few decent local eateries around the plaza if you need to refuel before continuing the walk.',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r28b',
        authorName: 'Susana Gatmaitan',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Nothing spectacular on its own but a fine transit point. Traffic can get a bit heavy here so mind the crossings.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r28c',
        authorName: 'Efren Dalisay',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Locals hang out here in the evenings, good spot to see everyday Intramuros life outside the tourist bubble of the fort itself.',
        publishedAt: DateTime.now().subtract(const Duration(days: 49)),
      ),
    ],
    'baluarte-de-santa-barbara': [
      Review(
        id: 'r29a',
        authorName: 'Gregorio Feliciano',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Mostly viewed from outside since access inside the bastion itself is restricted. Still an interesting piece of the northern waterfront wall line.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r29b',
        authorName: 'Angelita Fajardo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'If you are doing the full wall walk near Fort Santiago you will pass this bastion naturally. Worth a photo stop even if you cannot go inside.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r29c',
        authorName: 'Ramon Belarmino',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Not heavily signposted, easy to walk right past it without realizing what you are looking at. Worth reading up on the fortification names beforehand.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'colegio-de-san-juan-de-letran': [
      Review(
        id: 'r30a',
        authorName: 'Fr. Simplicio Uy, O.P.',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'As an alumnus visiting decades later, seeing the campus still standing since 1620 never stops feeling surreal. One of only two schools left inside the walls, and it shows in the pride of the students here.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r30b',
        authorName: 'Carmela Dizon',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Just walking past the gates and seeing "founded 1620" on the marker puts things in perspective. Not open for casual tourist entry though, so plan to view from the street.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Review(
        id: 'r30c',
        authorName: 'Benito Cachero',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A living piece of Intramuros history that most tourists skip because it is an active school. If you have Dominican or Letran connections it is worth the detour.',
        publishedAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
    ],
    'mapua-university-intramuros': [
      Review(
        id: 'r31a',
        authorName: 'Kevin Ang',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Studied here for four years, the old administration building facade on Muralla Street always felt like a landmark in its own right, separate from the rest of the school.',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r31b',
        authorName: 'Trisha Manlapig',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Interesting to see a modern engineering university operating inside a 16th century walled city. Campus is not really set up for tourist visits but the exterior is worth a glance while walking Muralla.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r31c',
        authorName: 'Godfrey Lao',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Just passed by on a walking tour, guide mentioned it briefly. Would have liked more context on why the Mapua family chose Intramuros specifically back in 1951.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'pamantasan-ng-lungsod-ng-maynila': [
      Review(
        id: 'r32a',
        authorName: 'Arlene Fuentebella',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Proud PLM alumna here. Being the only city-government-funded university in the whole country and sitting right inside the walls of Intramuros is a detail most people do not realize.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r32b',
        authorName: 'Xavier Rosario',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Gusaling Katipunan building has a nice mid-century civic look to it that stands out from the colonial-era stonework elsewhere in Intramuros. Grounds are quiet outside of class hours.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r32c',
        authorName: 'Dolores Camacho',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Learned about the scholarship program for Manila public high school top graduates while touring nearby, genuinely impressive mission for a public university.',
        publishedAt: DateTime.now().subtract(const Duration(days: 49)),
      ),
    ],
    'revellin-de-puerta-real-de-bagumbayan': [
      Review(
        id: 'r33a',
        authorName: 'Lorenzo Abueva',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Easy to overlook since it blends into the wider Puerta Real Gardens complex. History buffs will appreciate the outer-defense concept even if it is not visually dramatic.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r33b',
        authorName: 'Perlita Songco',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Combine with the Puerta Real Gardens visit since they are basically the same stop. Nice to understand how the ravelin protected the gate from direct attack.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r33c',
        authorName: 'Hector Villamor',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Signage could be clearer distinguishing this ravelin from the main Puerta Real gate itself. Worth a mention if a guide is walking you through the area.',
        publishedAt: DateTime.now().subtract(const Duration(days: 56)),
      ),
    ],
    'baluarillo-de-san-juan': [
      Review(
        id: 'r34a',
        authorName: 'Marco Villanueva',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The seafront bastion is strikingly photogenic at sunset. You can trace the old wall line from here all the way south.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r34b',
        authorName: 'Yuki Tanaka',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Small but atmospheric. A quiet corner of Intramuros most tourists miss.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r34c',
        authorName: 'Patricia Dela Cruz',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Great spot to appreciate the coastal defence system. The stonework is well-preserved.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r34d',
        authorName: 'David Park',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Standing on the seafront wall here gives you perspective on how massive the old fortifications were.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'baluartillo-de-san-jose': [
      Review(
        id: 'r35a',
        authorName: 'Carlos Reyes',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Part of the interconnected seafront defences. The coastal views from here are lovely.',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r35b',
        authorName: 'Mei Lin Chen',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Fascinating to see how this links up with San Juan and the other coastal bastions.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r35c',
        authorName: 'Jake Morrison',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'An underrated fortification. Quiet, scenic, and surprisingly intact.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'reducto-de-san-pedro': [
      Review(
        id: 'r36a',
        authorName: 'Angelo Mendoza',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The compact redoubt shape is unusual. You can still see where ammunition was stored centuries ago.',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r36b',
        authorName: 'Sarah Winters',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'A hidden gem on the southwestern wall. The heritage ruin has real atmosphere.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r36c',
        authorName: 'Jun Park',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Interesting stop for anyone studying colonial-era military architecture.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'puerta-del-parian-revellin-del-parian': [
      Review(
        id: 'r37a',
        authorName: 'Bea Lim',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the original 1593 gates! The Parian market history makes this gate unique among all the entrances.',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r37b',
        authorName: 'Michael Thompson',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The restoration work done between 1967 and 1982 is impressive. The revellin adds a dramatic forward-defence dimension.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r37c',
        authorName: 'Rina Aquino',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'I loved learning about the Chinese merchant connection. The gate tells a story about trade and diversity in old Manila.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r37d',
        authorName: 'Kenji Ito',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A living piece of 16th-century architecture. The gate and revellin together are very photogenic.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'puerta-isabel-ii': [
      Review(
        id: 'r38a',
        authorName: 'Anna Reyes',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The Queen Isabel statue in front makes it unmistakable. The last gate ever built in the walls—opened in 1861.',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r38b',
        authorName: 'Tom Bradley',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Restored beautifully in 1966 after wartime damage. Love the contrast between old stonework and the city beyond.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r38c',
        authorName: 'Mika Santos',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Standing beneath the arch, you can imagine the crowds heading toward Binondo and the Bridge of Spain.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r38d',
        authorName: 'Raj Patel',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The Isabel II monument adds a regal touch to an already impressive gateway.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'foro-de-intramuros': [
      Review(
        id: 'r39a',
        authorName: 'Sofia Hernandez',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Attended a cultural performance here—the venue has wonderful acoustics and an intimate atmosphere.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r39b',
        authorName: 'Daniel Kim',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Great space for events in the heart of the walled city. The heritage setting makes every show special.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r39c',
        authorName: 'Liza Manalo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Caught a community event celebrating Filipino heritage. The programming is always thoughtful.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'fr-george-willman-museum': [
      Review(
        id: 'r40a',
        authorName: 'Father Miguel Torres',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'A touching tribute to the Jesuit who spent his life rebuilding Intramuros after the war. Deeply inspiring.',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r40b',
        authorName: 'Karen Liu',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Small museum but packed with meaning. The story of preservation after WWII destruction is powerful.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r40c',
        authorName: 'Hannah Fischer',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Wonderful to learn about the people behind Intramuros restoration. The photos and documents are well-curated.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'ncca-gallery': [
      Review(
        id: 'r41a',
        authorName: 'Althea Reyes',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Free admission and rotating exhibits by emerging Filipino artists. Every visit is different.',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r41b',
        authorName: 'Nathan Brooks',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A welcome creative oasis in the middle of historic Intramuros. The young artists featured are talented.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r41c',
        authorName: 'Jessa Villanueva',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Since 2009 this gallery has championed new voices in Filipino art. Proud of our NCCA.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'bagumbayan-light-and-sound-museum': [
      Review(
        id: 'r42a',
        authorName: 'Paolo Gutierrez',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The Rizal narrative brought to life through immersive light shows. I felt like I was there in 1896.',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r42b',
        authorName: 'Lisa Chang',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The guided audio-visual journey is absolutely captivating. Best museum experience in Intramuros.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r42c',
        authorName: 'Ramon Torres',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The narrated presentation about Philippine history is emotionally powerful. Allow at least an hour.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r42d',
        authorName: 'Nico Dela Peña',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'If you visit only one museum in Intramuros, make it this one. The Rizal story has never been told better.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'chamber-of-commerce': [
      Review(
        id: 'r43a',
        authorName: 'Ricardo Lim',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A quiet historic landmark that recalls when Intramuros was the mercantile heart of Manila.',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r43b',
        authorName: 'Priya Sharma',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Interesting to think about the commercial history layered under the fortifications and churches.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r43c',
        authorName: 'Vincent Cruz',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Mostly an exterior stop, but the colonial-period trade history context is worth appreciating.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'aduana-intendencia': [
      Review(
        id: 'r44a',
        authorName: 'Isabel Gonzales',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The old customs house at Plaza España tells the story of colonial trade and governance in one building.',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r44b',
        authorName: 'Mark Henderson',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Impressive facade on Soriano Avenue. The Intendencia housed government offices across multiple eras.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r44c',
        authorName: 'Luz Ramos',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Standing at the corner of Muralla Street, you can picture the customs inspectors of the Spanish period.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
    ],
    'plaza-de-santo-tomas': [
      Review(
        id: 'r45a',
        authorName: 'Gabriel Mercado',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A pleasant open space for a rest between visiting heritage landmarks. Shaded and peaceful.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r45b',
        authorName: 'Yuna Park',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Part of the planned urban layout of the walled city. A nice quiet stop on Santo Tomas Street.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r45c',
        authorName: 'Antonio Bautista',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'I love how the plazas of Intramuros tell the story of Spanish urban planning. This one is underrated.',
        publishedAt: DateTime.now().subtract(const Duration(days: 49)),
      ),
    ],
    'plaza-espana': [
      Review(
        id: 'r46a',
        authorName: 'Joaquin Luna',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The monument to King Philip II is striking—this is the man the Philippines was named after. A powerful spot.',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r46b',
        authorName: 'Sophie Martin',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The triangular shape formed by three intersecting streets creates an interesting urban space.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r46c',
        authorName: 'Rafael Andrada',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Near the Aduana Building and full of colonial-era significance. The Philip II statue is a must-see.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r46d',
        authorName: 'Tomas Villanueva',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Soriano, Solana, and Muralla converge here. The plaza captures the layered history of the walled city.',
        publishedAt: DateTime.now().subtract(const Duration(days: 42)),
      ),
    ],
    'manila-high-school': [
      Review(
        id: 'r47a',
        authorName: 'Teacher Marian Lopez',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A public school inside the walled city—our students walk past centuries of history every day.',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r47b',
        authorName: 'Eric Johnson',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Unique to see a working public school within the fortified walls of old Manila.',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r47c',
        authorName: 'Jenny Aguilar',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The educational presence inside Intramuros keeps the district alive and connected to the community.',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ],
    'lyceum-of-the-philippines-university': [
      Review(
        id: 'r48a',
        authorName: 'Chef Anya Reyes',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            "LPU's tourism and hospitality program is perfect for Intramuros. The campus buzzes with culinary students.",
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r48b',
        authorName: 'Mark Laurel',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Founded by Dr. Jose P. Laurel in 1952. The university carries his vision of accessible education.',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r48c',
        authorName: 'Samantha Chua',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'The Intramuros Consortium connection means LPU students engage directly with heritage preservation.',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Review(
        id: 'r48d',
        authorName: 'Bianca Torres',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'LPU on Muralla Street is where future tourism leaders train surrounded by centuries of history.',
        publishedAt: DateTime.now().subtract(const Duration(days: 49)),
      ),
    ],
  };

  // ─── Accessibility feature seeds kept from the original native build ──────
  static final Map<String, List<AccessibilityFeature>> _accessibilityBySiteId =
      {
        'fort-santiago': [
          // Cross-checked against OSM/Nominatim: Fort Santiago's real
          // footprint is bounded by roughly lat 14.5935-14.5954,
          // lng 120.9689-120.9712 (Nominatim way/331784458, the fort
          // gate: 14.5938751, 120.9706147 -- the same source used for
          // this site's own verified main-pin coordinate below). The
          // previous af1/af3 coordinates (lng ~120.9720-120.9722) sat
          // east of that boundary, on/across the Pasig River bank, not
          // inside the fort. These are generic accessibility-type
          // markers (not individually-named Google Maps listings), so
          // rather than inventing a specific verified business location,
          // they're re-anchored inside the fort's real, verified
          // footprint: af1 at the main gate/entrance itself (matching
          // this site's own coordinates field), af3 at a distinct point
          // well within the same footprint.
          const AccessibilityFeature(
            id: 'af1',
            name: 'Ramps & Elevators',
            description: 'Located near Main Entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5939, 120.9707),
          ),
          const AccessibilityFeature(
            id: 'af2',
            name: 'Braille / Voice',
            description: 'Voiceover mode active',
            type: AccessibilityType.brailleVoice,
          ),
          const AccessibilityFeature(
            id: 'af3',
            name: 'Vegetarian',
            description: '67m — open now',
            type: AccessibilityType.vegetarian,
            location: LatLng(14.5943, 120.9702),
          ),
        ],
        'san-agustin-church': [
          // Verified against Nominatim way/89571506 (San Agustin Church):
          // lat 14.5889053, lng bounding box 120.9750324-120.9756576.
          // The previous coordinate was already inside this footprint
          // (right at its western edge); nudged slightly east so the
          // pin sits unambiguously on the building rather than its edge.
          const AccessibilityFeature(
            id: 'af4',
            name: 'Ramps & Elevators',
            description: 'Ramp at side entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5889, 120.9752),
          ),
          const AccessibilityFeature(
            id: 'af5',
            name: 'Braille / Voice',
            description: 'Audio descriptions available',
            type: AccessibilityType.brailleVoice,
          ),
        ],
        'manila-cathedral': [
          // Verified against Nominatim/OSM way/331777144 (Manila
          // Cathedral): lat 14.5915057, lng 120.9736106. Previous
          // coordinate was already close (~25m off, within the
          // building); tightened to match, biased slightly south toward
          // Plaza Roma where the cathedral's main entrance faces.
          const AccessibilityFeature(
            id: 'af6',
            name: 'Ramps & Elevators',
            description: 'Wheelchair accessible main entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5914, 120.9736),
          ),
        ],
      };

  static const List<String> _defaultAudioGuideSiteIds = [
    'fort-santiago',
    'san-agustin-church',
  ];

  // ─── Public API ─────────────────────────────────────────────────────────────

  List<LocationModel> getAllLocations() {
    return _rawSites.map(_buildLocation).toList();
  }

  LocationModel getLocationById(String id) {
    final site = _rawSites.firstWhere((s) => s.id == id);
    return _buildLocation(site);
  }

  List<LocationModel> getRelatedLocations(LocationModel location) {
    final related = <LocationModel>[];
    for (final id in location.relatedPlaceIds) {
      final matches = _rawSites.where((s) => s.id == id);
      if (matches.isNotEmpty) related.add(_buildLocation(matches.first));
    }
    return related;
  }

  LocationModel _buildLocation(_RawSite site) {
    final reviews = _reviewsBySiteId[site.id] ?? const [];
    final rating = reviews.isNotEmpty
        ? reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length
        : 4.8;
    return LocationModel(
      id: site.id,
      name: site.name,
      subtitle: 'Intramuros, Manila',
      description: site.history,
      history: site.history,
      imageUrl: site.photo,
      galleryImages: [site.photo],
      rating: reviews.isNotEmpty
          ? double.parse(rating.toStringAsFixed(1))
          : 4.8,
      reviewCount: reviews.length,
      coordinates: site.coordinates,
      address: '${site.area}, Intramuros, Manila, Philippines',
      operatingHours:
          site.officialHours ??
          const OperatingHours(
            schedules: [
              DaySchedule(
                days: [1, 2, 3, 4, 5, 6, 7],
                openMinutes: 480,
                closeMinutes: 1080,
              ),
            ],
          ),
      ticketInfo:
          site.officialTicket ??
          TicketInfo(
            adultPrice: 0,
            studentPrice: 0,
            currency: '₱',
            notes: site.access,
          ),
      reviews: reviews,
      accessibilityFeatures: _accessibilityBySiteId[site.id] ?? const [],
      nearbyAmenities: const [],
      category: site.category,
      hasAudioGuide: _defaultAudioGuideSiteIds.contains(site.id),
      audioGuideLanguages: _defaultAudioGuideSiteIds.contains(site.id)
          ? const ['EN', 'FIL']
          : const [],
      type: site.type,
      note: site.note,
      highlights: site.highlights,
      visitNote: site.visitNote,
      relatedPlaceIds: site.relatedPlaceIds,
      budgetRange: site.budgetRange,
      hasWifi: site.hasWifi,
      hasSockets: site.hasSockets,
    );
  }
}
