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
  category; // Fortifications | Landmarks | Museums | Churches | Parks
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
      coordinates: const LatLng(14.5951, 120.9718),
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
      coordinates: const LatLng(14.5952, 120.9716),
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
      coordinates: const LatLng(14.5958, 120.9722),
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
      coordinates: const LatLng(14.5963, 120.9730),
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
      coordinates: const LatLng(14.5896, 120.9740),
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
      coordinates: const LatLng(14.5893, 120.9738),
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
      coordinates: const LatLng(14.5907, 120.9737),
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
      coordinates: const LatLng(14.5908, 120.9735),
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
      coordinates: const LatLng(14.5865, 120.9724),
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
      coordinates: const LatLng(14.5868, 120.9721),
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
      coordinates: const LatLng(14.5916, 120.9733),
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
      coordinates: const LatLng(14.5888, 120.9748),
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
      coordinates: const LatLng(14.5886, 120.9750),
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
      coordinates: const LatLng(14.5919, 120.9759),
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
      coordinates: const LatLng(14.5975, 120.9750),
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
      coordinates: const LatLng(14.5917, 120.9731),
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
      coordinates: const LatLng(14.5914, 120.9727),
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
      coordinates: const LatLng(14.5920, 120.9728),
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
      coordinates: const LatLng(14.5859, 120.9737),
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
      coordinates: const LatLng(14.5945, 120.9757),
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
      coordinates: const LatLng(14.5877, 120.9714),
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
      coordinates: const LatLng(14.5950, 120.9719),
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
      coordinates: const LatLng(14.5940, 120.9723),
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
      photo: 'https://intramuros.gov.ph/wp-content/uploads/2022/09/Barbara.png',
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
      coordinates: const LatLng(14.5962, 120.9727),
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
      coordinates: const LatLng(14.593500, 120.977556),
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
      coordinates: const LatLng(14.590833, 120.977778),
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
      coordinates: const LatLng(14.587000, 120.976000),
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
      coordinates: const LatLng(14.5857, 120.9740),
      relatedPlaceIds: ['puerta-real-gardens', 'baluarte-de-san-diego'],
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
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r2',
        authorName: 'John Rivera',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Beautiful historical site with well-preserved architecture. The gardens are peaceful and perfect for photos. Entrance fee is very affordable.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r3',
        authorName: 'Angela Cruz',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the best-preserved Spanish colonial structures in the Philippines. Walking through the dungeons gives you chills. Very educational experience.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r4',
        authorName: 'Carlos Mendoza',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Great place to learn about Philippine history. The fort has a somber but beautiful atmosphere. Bring water as it can get hot during midday.',
        relativeTime: '2 months ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r6',
        authorName: 'Miguel Torres',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Beautiful church with rich history. The museum attached has interesting artifacts from the colonial era. Worth the entrance fee.',
        relativeTime: '3 weeks ago',
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
        relativeTime: '5 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r8',
        authorName: 'David Aquino',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the most beautiful churches in the Philippines. The pipe organ concerts are a unique experience. Highly recommend visiting during mass.',
        relativeTime: '2 weeks ago',
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
        relativeTime: '3 weeks ago',
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
        relativeTime: '1 month ago',
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
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r11b',
        authorName: 'Jonas Ecleo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'You can really see the layers of excavation here, the 1587 foundation stones are still visible under the newer masonry. Bring sunscreen, there is barely any shade in the open circular court.',
        relativeTime: '5 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Review(
        id: 'r11c',
        authorName: 'Precious Andrade',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'We had our prenup shoot here and the caretakers were so accommodating. The archaeological layout is genuinely interesting even if you are not into photography.',
        relativeTime: '2 months ago',
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
        relativeTime: '4 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r12b',
        authorName: 'Grace Tolentino',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Small but dense with history. Get an actual guide if you can, the plaques alone do not do the story justice. The bronze footsteps marking his final walk are a nice touch outside.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r12c',
        authorName: 'Miko Salazar',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Required visit for anyone who took up Rizal in school. Seeing his actual handwriting in the exhibited letters made the textbook version of him feel like a real person.',
        relativeTime: '1 month ago',
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
        relativeTime: '6 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r13b',
        authorName: 'Ryan Custodio',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Pretty views of the Pasig but the smell from the river can be strong depending on the tide. Go around sunset when the breeze picks up.',
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r13c',
        authorName: 'Faith Barrientos',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Loved that this connects straight to the esplanade for a longer walk. Felt safe, well-lit in the early evening, and much less crowded than the main fort entrance.',
        relativeTime: '1 month ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r14b',
        authorName: 'Cherry Domingo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Underrated spot for river views of Manila. Bring your own water though, there are not a lot of vendors along this particular stretch yet.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r14c',
        authorName: 'Boyet Salonga',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'It is wild that this used to be an inaccessible industrial edge of the river. Now it is one of the calmest places in the whole walled city to just sit and watch the boats.',
        relativeTime: '2 months ago',
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
        relativeTime: '5 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r15b',
        authorName: 'Patrick Yumang',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Nice mix of cafes and souvenir shops built into the old house ground floors. A bit touristy in pricing but the ambiance makes up for it.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r15c',
        authorName: 'Sheena Aquino',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'This is the most Instagrammable corner of Intramuros in my opinion, and I have been to most of it. Go early before the tour groups arrive.',
        relativeTime: '6 weeks ago',
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
        relativeTime: '3 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r16b',
        authorName: 'Josefina Reburiano',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            "The reconstructed San Ignacio Church setting is beautiful on its own, aside from the exhibits. Staff were happy to explain the church's destruction and rebuilding history in detail.",
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r16c',
        authorName: 'Diego Formoso',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Newer venue so it is not as crowded yet. Worth checking their cultural programme schedule before visiting since there are sometimes live demonstrations.',
        relativeTime: '5 weeks ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r17b',
        authorName: 'Wilfredo Tumbaga',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Nice enough but limited seating. Gets a bit muddy near the edges after rain so watch your footing.',
        relativeTime: '4 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      Review(
        id: 'r17c',
        authorName: 'Aiza Villaflor',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'The trees here are old and give real shade, unlike a lot of the more exposed plazas in Intramuros. Underrated picnic spot honestly.',
        relativeTime: '2 months ago',
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
        relativeTime: '6 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r18b',
        authorName: 'Cecilia Roa',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Combine your ticket with the church visit next door, they flow into each other naturally. The trompe-l\'oeil ceiling painting in the old refectory is the highlight for me.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r18c',
        authorName: 'Randall Ku',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Dim lighting in some galleries which protects the artifacts but makes photos hard without a good camera. Still one of the better-curated religious museums in Manila.',
        relativeTime: '1 month ago',
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
        relativeTime: '4 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r19b',
        authorName: 'Melinda Tan-Uy',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Extremely thorough exhibits, budget at least two hours. The recreated ancestral house interior and the WWII memorial wall were both moving.',
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r19c',
        authorName: 'Oliver Gatchalian',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A bit out of the way compared to the other Intramuros stops but absolutely worth the extra walk. Wish more schools brought field trips here.',
        relativeTime: '5 weeks ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r20b',
        authorName: 'Jasmine Del Pilar',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Small museum, more of a quick stop than a full activity. The Bino sourdipili liqueur samples were the best part honestly, not so much the exhibit itself.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r20c',
        authorName: 'Marco Ilagan',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Loved the family archive photos going back five generations. Book the guided tour and tasting combo if it is available, staff know a lot of trivia that is not on the placards.',
        relativeTime: '6 weeks ago',
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
        relativeTime: '2 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r21b',
        authorName: 'Bienvenido Cruz',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Lots of calesa drivers waiting around here, easy to just flag one down for a short loop of the district. Plaza itself is clean and well-maintained.',
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r21c',
        authorName: 'Nathalie Perez',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Free, open, and shaded enough to just sit for a while between museum visits. Great starting point if you are planning your walking route for the day.',
        relativeTime: '1 month ago',
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
        relativeTime: '5 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r22b',
        authorName: 'Luz Manalastas',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Government building so do not expect a tourist experience inside, but architecturally it fits right into the Plaza Roma ensemble with the cathedral.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r22c',
        authorName: 'Julius Ferrolino',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Mostly worth it for the historical context of colonial Manila governance. Not much to actually do here besides admire the exterior.',
        relativeTime: '2 months ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r23b',
        authorName: 'Danilo Quiambao',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Good vantage point toward the cathedral and Plaza Roma. Worth a quick stop if you are already walking that stretch of General Luna.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r23c',
        authorName: 'Yolanda Mercado',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Not much signage explaining what used to stand here, had to look it up myself afterward. Would benefit from a proper historical marker.',
        relativeTime: '7 weeks ago',
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
        relativeTime: '4 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      Review(
        id: 'r24b',
        authorName: 'Enrico Villaroman',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Nice garden to walk through even without an event happening. You can see where the old moat and ravelin used to be if you look at the ground contours.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r24c',
        authorName: 'Precy Naval',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'One of the few Intramuros gates you can actually walk through and linger in rather than just photograph from outside. Highly recommend for golden hour shots.',
        relativeTime: '5 weeks ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r25b',
        authorName: 'Armando Legaspi',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Small and easy to miss if you are not specifically looking for it near the old Revellin del Parian site. Nice for a five minute breather though.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r25c',
        authorName: 'Concepcion Rivas',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Symbolically nice given how much of Southeast Asian trade history passed through this port city. Peaceful, uncrowded, good for a slow morning walk.',
        relativeTime: '6 weeks ago',
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
        relativeTime: '3 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r26b',
        authorName: 'Bernadette Sarmiento',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Compact pocket park, took maybe ten minutes to walk through. Close enough to the Santa Lucia gate area to combine into the same stop.',
        relativeTime: '4 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 28)),
      ),
      Review(
        id: 'r26c',
        authorName: 'Reynaldo Pascual',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Some of the reliefs could use cleaning but overall a nice free stop. Good shade from the surrounding trees during midday heat.',
        relativeTime: '2 months ago',
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
        relativeTime: '2 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Review(
        id: 'r27b',
        authorName: 'Imelda Bautista-Ong',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Very exposed to the sun with little shade in the open plaza, go early or late afternoon. The view of the citadel walls from the center is worth it though.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r27c',
        authorName: 'Alfonso Trinidad',
        authorPhotoUrl: '',
        rating: 5.0,
        text:
            'Occasional cultural performances happen here on weekends, we got lucky and caught a folk dance group rehearsing. Ask the guards about the schedule.',
        relativeTime: '5 weeks ago',
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
        relativeTime: '6 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      Review(
        id: 'r28b',
        authorName: 'Susana Gatmaitan',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Nothing spectacular on its own but a fine transit point. Traffic can get a bit heavy here so mind the crossings.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r28c',
        authorName: 'Efren Dalisay',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Locals hang out here in the evenings, good spot to see everyday Intramuros life outside the tourist bubble of the fort itself.',
        relativeTime: '7 weeks ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r29b',
        authorName: 'Angelita Fajardo',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'If you are doing the full wall walk near Fort Santiago you will pass this bastion naturally. Worth a photo stop even if you cannot go inside.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r29c',
        authorName: 'Ramon Belarmino',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Not heavily signposted, easy to walk right past it without realizing what you are looking at. Worth reading up on the fortification names beforehand.',
        relativeTime: '2 months ago',
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
        relativeTime: '2 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
      Review(
        id: 'r30b',
        authorName: 'Carmela Dizon',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Just walking past the gates and seeing "founded 1620" on the marker puts things in perspective. Not open for casual tourist entry though, so plan to view from the street.',
        relativeTime: '5 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 35)),
      ),
      Review(
        id: 'r30c',
        authorName: 'Benito Cachero',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'A living piece of Intramuros history that most tourists skip because it is an active school. If you have Dominican or Letran connections it is worth the detour.',
        relativeTime: '2 months ago',
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
        relativeTime: '3 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      Review(
        id: 'r31b',
        authorName: 'Trisha Manlapig',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Interesting to see a modern engineering university operating inside a 16th century walled city. Campus is not really set up for tourist visits but the exterior is worth a glance while walking Muralla.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r31c',
        authorName: 'Godfrey Lao',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Just passed by on a walking tour, guide mentioned it briefly. Would have liked more context on why the Mapua family chose Intramuros specifically back in 1951.',
        relativeTime: '6 weeks ago',
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
        relativeTime: '5 days ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Review(
        id: 'r32b',
        authorName: 'Xavier Rosario',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Gusaling Katipunan building has a nice mid-century civic look to it that stands out from the colonial-era stonework elsewhere in Intramuros. Grounds are quiet outside of class hours.',
        relativeTime: '3 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 21)),
      ),
      Review(
        id: 'r32c',
        authorName: 'Dolores Camacho',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Learned about the scholarship program for Manila public high school top graduates while touring nearby, genuinely impressive mission for a public university.',
        relativeTime: '7 weeks ago',
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
        relativeTime: '1 week ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Review(
        id: 'r33b',
        authorName: 'Perlita Songco',
        authorPhotoUrl: '',
        rating: 4.0,
        text:
            'Combine with the Puerta Real Gardens visit since they are basically the same stop. Nice to understand how the ravelin protected the gate from direct attack.',
        relativeTime: '1 month ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Review(
        id: 'r33c',
        authorName: 'Hector Villamor',
        authorPhotoUrl: '',
        rating: 3.0,
        text:
            'Signage could be clearer distinguishing this ravelin from the main Puerta Real gate itself. Worth a mention if a guide is walking you through the area.',
        relativeTime: '8 weeks ago',
        publishedAt: DateTime.now().subtract(const Duration(days: 56)),
      ),
    ],
  };

  // ─── Accessibility feature seeds kept from the original native build ──────
  static final Map<String, List<AccessibilityFeature>> _accessibilityBySiteId =
      {
        'fort-santiago': [
          const AccessibilityFeature(
            id: 'af1',
            name: 'Ramps & Elevators',
            description: 'Located near Main Entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5955, 120.9720),
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
            location: LatLng(14.5948, 120.9722),
          ),
        ],
        'san-agustin-church': [
          const AccessibilityFeature(
            id: 'af4',
            name: 'Ramps & Elevators',
            description: 'Ramp at side entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5889, 120.9750),
          ),
          const AccessibilityFeature(
            id: 'af5',
            name: 'Braille / Voice',
            description: 'Audio descriptions available',
            type: AccessibilityType.brailleVoice,
          ),
        ],
        'manila-cathedral': [
          const AccessibilityFeature(
            id: 'af6',
            name: 'Ramps & Elevators',
            description: 'Wheelchair accessible main entrance',
            type: AccessibilityType.ramps,
            location: LatLng(14.5917, 120.9735),
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
    );
  }
}
