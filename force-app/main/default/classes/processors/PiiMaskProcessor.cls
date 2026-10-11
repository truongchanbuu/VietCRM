public with sharing class PiiMaskProcessor implements IReportPostProcessor {
  public ReportResult process(ReportResult result, List<String> fields) {
    Boolean mayViewPii = FeatureManagement.checkPermission('View_PII');
    Boolean maskingEnabled = CaseFeatureFlags.isEnabled('PiiMasking');
    if (!maskingEnabled && mayViewPii)
      return result;
    for (SObject record : result.records)
      maskRecord(record, 0);
    return result;
  }

  private static void maskRecord(SObject record, Integer depth) {
    if (record == null || depth > 3)
      return;
    Map<String, Object> populated = record.getPopulatedFieldsAsMap();
    Map<String, Schema.SObjectField> fieldTokens = record.getSObjectType()
      .getDescribe()
      .fields.getMap();
    for (String fieldName : populated.keySet()) {
      Object value = populated.get(fieldName);
      if (value == null)
        continue;
      Schema.SObjectField fieldToken = fieldTokens.get(fieldName);
      if (fieldToken == null) {
        if (value instanceof SObject)
          maskRecord((SObject) value, depth + 1);
        continue;
      }
      Schema.DisplayType type = fieldToken.getDescribe().getType();
      if (
        type == Schema.DisplayType.EMAIL ||
        type == Schema.DisplayType.PHONE
      ) {
        record.put(fieldName, maskValue(String.valueOf(value), type));
      } else if (value instanceof SObject) {
        maskRecord((SObject) value, depth + 1);
      }
    }
  }

  private static String maskValue(String value, Schema.DisplayType type) {
    if (type == Schema.DisplayType.EMAIL) {
      Integer at = value.indexOf('@');
      if (at <= 0)
        return '***';
      return value.substring(0, 1) + '***' + value.substring(at);
    }
    if (value.length() <= 4)
      return '****';
    return value.substring(0, 2) +
      '******' +
      value.substring(value.length() - 2);
  }
}
