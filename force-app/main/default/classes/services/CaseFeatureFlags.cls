public with sharing class CaseFeatureFlags {
  private static Map<String, Boolean> cache = new Map<String, Boolean>();

  public static Boolean isEnabled(String flagName) {
    if (String.isBlank(flagName))
      return false;
    String key = flagName.trim().toLowerCase();
    if (!cache.containsKey(key)) {
      Boolean enabled = false;
      for (FeatureFlag__mdt flag : FeatureFlag__mdt.getAll().values()) {
        if (
          flag.DeveloperName != null &&
          flag.DeveloperName.toLowerCase() == key
        ) {
          enabled = flag.IsEnabled__c == true;
          break;
        }
      }
      cache.put(key, enabled);
    }
    return cache.get(key);
  }
}
