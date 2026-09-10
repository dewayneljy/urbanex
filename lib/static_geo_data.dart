/// Static reference data that has NO live open-data API in Malaysia, so it
/// is bundled with the app instead of fetched. Everything else (income,
/// population, electricity/water access, schools, forest reserves, crime)
/// is pulled live from data.gov.my in DataService.
///
/// - [districtAreaKm2]: approximate land area per district, used only to
///   turn live population figures into population density. Figures are
///   rounded reference values (source: DOSM/JUPEM district gazettes) -
///   extend this map with more districts as needed.
/// - [stateForestReserveKm2]: approximate permanent forest reserve area
///   per state, used only as a fallback for the rare state/year where the
///   live `forest_reserve_state` dataset has no row (e.g. the federal
///   territories, which are mostly urbanised and often absent from that
///   dataset).
library static_geo_data;

/// All 16 Malaysian states/federal territories, as used by the
/// data.gov.my `state` column.
const List<String> kAllStates = [
  'Johor',
  'Kedah',
  'Kelantan',
  'Melaka',
  'Negeri Sembilan',
  'Pahang',
  'Perak',
  'Perlis',
  'Pulau Pinang',
  'Sabah',
  'Sarawak',
  'Selangor',
  'Terengganu',
  'W.P. Kuala Lumpur',
  'W.P. Labuan',
  'W.P. Putrajaya',
];

/// A curated set of districts per state (data.gov.my exposes all 160;
/// this list has been broadened from the original handful per state to
/// give "Show matching districts" a wider, more representative spread,
/// while staying manageable to maintain by hand). Melaka, Perlis, and the
/// federal territories are already complete (those states/FTs genuinely
/// only have that many administrative districts).
const Map<String, List<String>> kDistrictsByState = {
  'Johor': ['Johor Bahru', 'Batu Pahat', 'Muar', 'Kluang', 'Kota Tinggi', 'Pontian', 'Segamat', 'Mersing'],
  'Kedah': ['Kota Setar', 'Kulim', 'Langkawi', 'Sungai Petani', 'Baling', 'Yan', 'Padang Terap', 'Kubang Pasu'],
  'Kelantan': ['Kota Bharu', 'Pasir Mas', 'Tanah Merah', 'Machang', 'Tumpat', 'Gua Musang', 'Kuala Krai'],
  'Melaka': ['Melaka Tengah', 'Alor Gajah', 'Jasin'],
  'Negeri Sembilan': ['Seremban', 'Port Dickson', 'Rembau', 'Jempol', 'Kuala Pilah', 'Tampin', 'Jelebu'],
  'Pahang': ['Kuantan', 'Temerloh', 'Bentong', 'Pekan', 'Cameron Highlands', 'Raub', 'Jerantut'],
  'Perak': ['Kinta', 'Manjung', 'Larut, Matang dan Selama', 'Kuala Kangsar', 'Hilir Perak', 'Kerian', 'Batang Padang'],
  'Perlis': ['Perlis'],
  'Pulau Pinang': ['Timur Laut', 'Seberang Perai Tengah', 'Seberang Perai Utara', 'Barat Daya', 'Seberang Perai Selatan'],
  'Sabah': ['Kota Kinabalu', 'Sandakan', 'Tawau', 'Lahad Datu', 'Keningau', 'Papar', 'Beaufort'],
  'Sarawak': ['Kuching', 'Miri', 'Sibu', 'Bintulu', 'Sri Aman', 'Sarikei', 'Limbang'],
  'Selangor': ['Petaling', 'Gombak', 'Klang', 'Hulu Langat', 'Sepang', 'Kuala Langat', 'Kuala Selangor', 'Hulu Selangor', 'Sabak Bernam'],
  'Terengganu': ['Kuala Terengganu', 'Kemaman', 'Dungun', 'Hulu Terengganu', 'Marang', 'Setiu', 'Besut'],
  'W.P. Kuala Lumpur': ['Kuala Lumpur'],
  'W.P. Labuan': ['Labuan'],
  'W.P. Putrajaya': ['Putrajaya'],
};

/// Approximate land area (km2) per district - used to compute population
/// density from the live population figures.
const Map<String, double> districtAreaKm2 = {
  // Johor
  'Johor Bahru': 1880,
  'Batu Pahat': 1885,
  'Muar': 1275,
  'Kluang': 2621,
  'Kota Tinggi': 3488,
  'Pontian': 1116,
  'Segamat': 2352,
  'Mersing': 2841,
  // Kedah
  'Kota Setar': 675,
  'Kulim': 793,
  'Langkawi': 478,
  'Sungai Petani': 936, // Kuala Muda
  'Baling': 1704,
  'Yan': 475,
  'Padang Terap': 1341,
  'Kubang Pasu': 794,
  // Kelantan
  'Kota Bharu': 466,
  'Pasir Mas': 466,
  'Tanah Merah': 969,
  'Machang': 530,
  'Tumpat': 169,
  'Gua Musang': 7943,
  'Kuala Krai': 2160,
  // Melaka
  'Melaka Tengah': 587,
  'Alor Gajah': 660,
  'Jasin': 663,
  // Negeri Sembilan
  'Seremban': 927,
  'Port Dickson': 578,
  'Rembau': 538,
  'Jempol': 1465,
  'Kuala Pilah': 950,
  'Tampin': 903,
  'Jelebu': 1587,
  // Pahang
  'Kuantan': 2960,
  'Temerloh': 1963,
  'Bentong': 1852,
  'Pekan': 3727,
  'Cameron Highlands': 712,
  'Raub': 2269,
  'Jerantut': 6533,
  // Perak
  'Kinta': 1477,
  'Manjung': 989,
  'Larut, Matang dan Selama': 2062,
  'Kuala Kangsar': 2483,
  'Hilir Perak': 1233,
  'Kerian': 813,
  'Batang Padang': 2632,
  // Perlis
  'Perlis': 810,
  // Pulau Pinang
  'Timur Laut': 121,
  'Seberang Perai Tengah': 231,
  'Seberang Perai Utara': 331,
  'Barat Daya': 275,
  'Seberang Perai Selatan': 386,
  // Sabah
  'Kota Kinabalu': 351,
  'Sandakan': 8676,
  'Tawau': 5251,
  'Lahad Datu': 7369,
  'Keningau': 3536,
  'Papar': 1113,
  'Beaufort': 1183,
  // Sarawak
  'Kuching': 1863,
  'Miri': 9764,
  'Sibu': 5251,
  'Bintulu': 8000,
  'Sri Aman': 2246,
  'Sarikei': 1793,
  'Limbang': 3978,
  // Selangor
  'Petaling': 491,
  'Gombak': 645,
  'Klang': 573,
  'Hulu Langat': 809,
  'Sepang': 599,
  'Kuala Langat': 843,
  'Kuala Selangor': 1181,
  'Hulu Selangor': 1782,
  'Sabak Bernam': 951,
  // Terengganu
  'Kuala Terengganu': 605,
  'Kemaman': 2536,
  'Dungun': 2735,
  'Hulu Terengganu': 3555,
  'Marang': 649,
  'Setiu': 1279,
  'Besut': 1245,
  // Federal territories
  'Kuala Lumpur': 243,
  'Labuan': 91,
  'Putrajaya': 49,
};

/// Approximate permanent forest reserve area (km2) per state - used only
/// as a fallback when the live `forest_reserve_state` dataset has no row
/// for that state/year (e.g. the small, mostly-urban federal territories).
const Map<String, double> stateForestReserveKm2 = {
  'Johor': 9600,
  'Kedah': 2700,
  'Kelantan': 6300,
  'Melaka': 200,
  'Negeri Sembilan': 2100,
  'Pahang': 21500,
  'Perak': 15300,
  'Perlis': 220,
  'Pulau Pinang': 300,
  'Sabah': 36000,
  'Sarawak': 43000,
  'Selangor': 2900,
  'Terengganu': 6900,
  'W.P. Kuala Lumpur': 8,
  'W.P. Labuan': 5,
  'W.P. Putrajaya': 2,
};



