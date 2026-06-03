class CountryMapper {
  static final Map<String, String> _isoToName = {
    'AF': 'Afghanistan', 'AL': 'Albania', 'DZ': 'Algeria', 'AR': 'Argentina',
    'AU': 'Australia', 'AT': 'Austria', 'BD': 'Bangladesh', 'BE': 'Belgium',
    'BR': 'Brazil', 'CA': 'Canada', 'CL': 'Chile', 'CN': 'China',
    'CO': 'Colombia', 'CZ': 'Czechia', 'DK': 'Denmark', 'EG': 'Egypt',
    'FI': 'Finland', 'FR': 'France', 'DE': 'Germany', 'GR': 'Greece',
    'HU': 'Hungary', 'IN': 'India', 'ID': 'Indonesia', 'IR': 'Iran',
    'IQ': 'Iraq', 'IE': 'Ireland', 'IL': 'Israel', 'IT': 'Italy',
    'JP': 'Japan', 'KR': 'South Korea', 'MY': 'Malaysia', 'MX': 'Mexico',
    'MA': 'Morocco', 'NL': 'Netherlands', 'NZ': 'New Zealand', 'NG': 'Nigeria',
    'NO': 'Norway', 'PK': 'Pakistan', 'PE': 'Peru', 'PH': 'Philippines',
    'PL': 'Poland', 'PT': 'Portugal', 'RO': 'Romania', 'RU': 'Russia',
    'SA': 'Saudi Arabia', 'SG': 'Singapore', 'ZA': 'South Africa', 'ES': 'Spain',
    'SE': 'Sweden', 'CH': 'Switzerland', 'TW': 'Taiwan', 'TH': 'Thailand',
    'TR': 'Turkey', 'UA': 'Ukraine', 'GB': 'United Kingdom', 'US': 'United States',
    'VN': 'Vietnam'
  };

  static String getName(String iso) {
    return _isoToName[iso] ?? iso;
  }
  
  static Map<String, String> get all => _isoToName;

  static String getFlagEmoji(String iso) {
    if (iso.length != 2) return "🗺️";
    int flagOffset = 0x1F1E6;
    int asciiOffset = 0x41;
    int firstChar = iso.codeUnitAt(0) - asciiOffset + flagOffset;
    int secondChar = iso.codeUnitAt(1) - asciiOffset + flagOffset;
    return String.fromCharCode(firstChar) + String.fromCharCode(secondChar);
  }
}
