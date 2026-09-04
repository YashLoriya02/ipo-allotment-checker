abstract class StorageKeys {
  static const applications = 'applications';
  static const panProfiles = 'pan_profiles';
  static const themeMode = 'theme_mode';
  static const discoverIpoType = 'discover_ipo_type';
  static const cachedIpos = 'cached_ipos';
  static const lastIpoRefresh = 'last_ipo_refresh';

  static String pan(String profileId) => 'pan_$profileId';
}
