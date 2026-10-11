public with sharing class SchemaHelper {
  private static Map<String, Schema.SObjectType> objectTypes;
  private static Map<String, Set<String>> accessibleFields = new Map<String, Set<String>>();
  private static Map<String, Schema.DescribeFieldResult> resolvedFields = new Map<String, Schema.DescribeFieldResult>();
  private static Map<String, String> normalizedPaths = new Map<String, String>();

  @TestVisible
  private static Integer globalDescribeCalls = 0;

  public static Schema.SObjectType getSObjectType(String objectName) {
    if (String.isBlank(objectName)) {
      throw new ConfigReportException('Object name is required.');
    }
    loadObjectTypes();
    Schema.SObjectType result = objectTypes.get(
      objectName.trim().toLowerCase()
    );
    if (result == null) {
      throw new ConfigReportException('Unknown object: ' + objectName);
    }
    return result;
  }

  public static Set<String> getAccessibleFields(String objectName) {
    Schema.SObjectType token = getSObjectType(objectName);
    String key =
      UserInfo.getUserId() +
      ':' +
      token.getDescribe().getName().toLowerCase();
    if (!accessibleFields.containsKey(key)) {
      Set<String> result = new Set<String>();
      for (
        Schema.SObjectField fieldToken : token.getDescribe()
          .fields.getMap()
          .values()
      ) {
        if (fieldToken.getDescribe().isAccessible()) {
          result.add(fieldToken.getDescribe().getName());
        }
      }
      accessibleFields.put(key, result);
    }
    return new Set<String>(accessibleFields.get(key));
  }

  public static Schema.DescribeFieldResult resolveFieldPath(
    String objectName,
    String path
  ) {
    resolvePath(objectName, path);
    return resolvedFields.get(cacheKey(objectName, path));
  }

  public static String normalizeFieldPath(String objectName, String path) {
    resolvePath(objectName, path);
    return normalizedPaths.get(cacheKey(objectName, path));
  }

  public static Boolean isFilterable(String objectName, String path) {
    return resolveFieldPath(objectName, path).isFilterable();
  }

  public static Boolean isSortable(String objectName, String path) {
    return resolveFieldPath(objectName, path).isSortable();
  }

  @TestVisible
  private static void resetCache() {
    objectTypes = null;
    accessibleFields.clear();
    resolvedFields.clear();
    normalizedPaths.clear();
    globalDescribeCalls = 0;
  }

  private static void loadObjectTypes() {
    if (objectTypes != null)
      return;
    objectTypes = new Map<String, Schema.SObjectType>();
    globalDescribeCalls++;
    Map<String, Schema.SObjectType> globalTypes = Schema.getGlobalDescribe();
    for (String name : globalTypes.keySet()) {
      objectTypes.put(name.toLowerCase(), globalTypes.get(name));
    }
  }

  private static void resolvePath(String objectName, String path) {
    String key = cacheKey(objectName, path);
    if (resolvedFields.containsKey(key))
      return;
    if (String.isBlank(path)) {
      throw new ConfigReportException('Field path is required.');
    }
    List<String> segments = path.trim().split('\\.');
    if (segments.size() > 3) {
      throw new ConfigReportException(
        'Field path exceeds three segments: ' + path
      );
    }
    List<Schema.SObjectType> currentTypes = new List<Schema.SObjectType>{
      getSObjectType(objectName)
    };
    List<String> normalized = new List<String>();
    Schema.DescribeFieldResult finalDescribe;
    for (Integer i = 0; i < segments.size(); i++) {
      String segment = segments[i];
      Boolean isLast = i == segments.size() - 1;
      if (String.isBlank(segment))
        throw invalidSegment(path, segment);
      if (isLast) {
        for (Schema.SObjectType currentType : currentTypes) {
          Schema.SObjectField token = findField(currentType, segment);
          if (token == null || !token.getDescribe().isAccessible())
            throw invalidSegment(path, segment);
          Schema.DescribeFieldResult describe = token.getDescribe();
          if (
            finalDescribe != null &&
            finalDescribe.getType() != describe.getType()
          ) {
            throw invalidSegment(path, segment);
          }
          finalDescribe = describe;
        }
        normalized.add(finalDescribe.getName());
      } else {
        List<Schema.SObjectType> nextTypes = new List<Schema.SObjectType>();
        String canonicalRelationship;
        for (Schema.SObjectType currentType : currentTypes) {
          Schema.DescribeFieldResult relationship = findRelationship(
            currentType,
            segment
          );
          if (relationship == null || !relationship.isAccessible())
            throw invalidSegment(path, segment);
          if (
            canonicalRelationship != null &&
            canonicalRelationship != relationship.getRelationshipName()
          ) {
            throw invalidSegment(path, segment);
          }
          canonicalRelationship = relationship.getRelationshipName();
          for (
            Schema.SObjectType referenceType : relationship.getReferenceTo()
          ) {
            if (!nextTypes.contains(referenceType))
              nextTypes.add(referenceType);
          }
        }
        if (nextTypes.isEmpty())
          throw invalidSegment(path, segment);
        normalized.add(canonicalRelationship);
        currentTypes = nextTypes;
      }
    }
    resolvedFields.put(key, finalDescribe);
    normalizedPaths.put(key, String.join(normalized, '.'));
  }

  private static Schema.SObjectField findField(
    Schema.SObjectType token,
    String name
  ) {
    for (String apiName : token.getDescribe().fields.getMap().keySet()) {
      if (apiName.equalsIgnoreCase(name))
        return token.getDescribe().fields.getMap().get(apiName);
    }
    return null;
  }

  private static Schema.DescribeFieldResult findRelationship(
    Schema.SObjectType token,
    String name
  ) {
    for (
      Schema.SObjectField fieldToken : token.getDescribe()
        .fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult field = fieldToken.getDescribe();
      if (
        field.getType() == Schema.DisplayType.REFERENCE &&
        field.getRelationshipName() != null &&
        field.getRelationshipName().equalsIgnoreCase(name)
      )
        return field;
    }
    return null;
  }

  private static String cacheKey(String objectName, String path) {
    return UserInfo.getUserId() +
      ':' +
      String.valueOf(objectName).trim().toLowerCase() +
      ':' +
      String.valueOf(path).trim().toLowerCase();
  }

  private static ConfigReportException invalidSegment(
    String path,
    String segment
  ) {
    return new ConfigReportException(
      'Invalid or inaccessible segment "' +
        segment +
        '" in path "' +
        path +
        '".'
    );
  }
}
