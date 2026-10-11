public with sharing class ConfigReportService {
  private static final Integer FALLBACK_MAX_ROWS = 100;
  private static Map<String, Report_Definition__mdt> definitionCache = new Map<String, Report_Definition__mdt>();
  @TestVisible
  private static Map<String, Report_Definition__mdt> definitionOverrides = new Map<String, Report_Definition__mdt>();

  public static ReportResult run(
    String definitionName,
    List<FilterCondition> extraFilters
  ) {
    if (!CaseFeatureFlags.isEnabled('ConfigReport')) {
      throw new ConfigReportException('Feature disabled');
    }
    if (String.isBlank(definitionName))
      throw new ConfigReportException('Report definition name is required.');
    Report_Definition__mdt definition = getDefinition(definitionName);
    List<String> errors = ReportDefinitionDomain.validate(definition);
    if (!errors.isEmpty())
      throw new ConfigReportException(String.join(errors, ' '));

    Integer maxRows = getMaxRows();
    ReportRequest request = new ReportRequest();
    request.objectName = definition.Object_Name__c;
    request.fields = splitCsv(definition.Fields__c);
    request.filters = parseDefaultFilters(definition);
    if (extraFilters != null)
      request.filters.addAll(extraFilters);
    request.limitSize = definition.Default_Limit__c.intValue();
    request.orderBy = request.fields.isEmpty() ? null : request.fields[0];
    request.orderDesc = false;

    ReportResult result = GenericSelector.execute(request, maxRows);
    new PiiMaskProcessor().process(result, request.fields);
    if (!String.isBlank(definition.Post_Processor_Class__c)) {
      result = invokeProcessor(
        definition.Post_Processor_Class__c,
        result,
        request.fields,
        definitionName
      );
    }
    return result;
  }

  @AuraEnabled(cacheable=false)
  public static ReportResult runForLwc(
    String definitionName,
    List<FilterCondition> extraFilters
  ) {
    try {
      return run(definitionName, extraFilters);
    } catch (ConfigReportException e) {
      if (e.getMessage() == 'Feature disabled')
        throw new AuraHandledException(
          'ConfigReport is currently unavailable.'
        );
      throw new AuraHandledException(
        'The report could not be run. Check the report name, filters, and your access.'
      );
    } catch (Exception e) {
      throw new AuraHandledException(
        'The report could not be run. Contact your administrator if the problem continues.'
      );
    }
  }

  public static Report_Definition__mdt getDefinition(String name) {
    String key = name.trim().toLowerCase();
    if (Test.isRunningTest() && definitionOverrides.containsKey(key))
      return definitionOverrides.get(key);
    if (!definitionCache.containsKey(key))
      definitionCache.put(key, Report_Definition__mdt.getInstance(name.trim()));
    Report_Definition__mdt result = definitionCache.get(key);
    if (result == null)
      throw new ConfigReportException('Unknown report definition: ' + name);
    return result;
  }

  @TestVisible
  private static Integer getMaxRows() {
    ReportConfig__c setting = ReportConfig__c.getInstance();
    if (
      setting == null ||
      setting.MaxRows__c == null ||
      setting.MaxRows__c <= 0
    )
      return FALLBACK_MAX_ROWS;
    return setting.MaxRows__c.intValue();
  }

  private static List<String> splitCsv(String csv) {
    List<String> values = new List<String>();
    if (String.isBlank(csv))
      return values;
    for (String value : csv.split(','))
      values.add(value.trim());
    return values;
  }

  private static List<FilterCondition> parseDefaultFilters(
    Report_Definition__mdt definition
  ) {
    List<FilterCondition> result = new List<FilterCondition>();
    if (String.isBlank(definition.Default_Filters__c))
      return result;
    try {
      List<Object> rawFilters = (List<Object>) JSON.deserializeUntyped(
        definition.Default_Filters__c
      );
      for (Object rawFilter : rawFilters) {
        Map<String, Object> values = (Map<String, Object>) rawFilter;
        result.add(
          new FilterCondition(
            (String) values.get('field'),
            (String) values.get('operator'),
            values.get('value')
          )
        );
      }
      return result;
    } catch (Exception e) {
      throw new ConfigReportException(
        'Invalid Default_Filters__c JSON for report ' +
          definition.DeveloperName +
          '.'
      );
    }
  }

  @TestVisible
  private static ReportResult invokeProcessor(
    String className,
    ReportResult result,
    List<String> fields,
    String definitionName
  ) {
    Type processorType = Type.forName(className.trim());
    if (processorType == null)
      throw new ConfigReportException(
        'Post-processor class was not found: ' + className
      );
    Object instance;
    try {
      instance = processorType.newInstance();
    } catch (Exception e) {
      throw new ConfigReportException(
        'Post-processor could not be constructed: ' + className
      );
    }
    IReportPostProcessor processor;
    try {
      processor = (IReportPostProcessor) instance;
    } catch (TypeException e) {
      throw new ConfigReportException(
        'Post-processor must implement IReportPostProcessor: ' + className
      );
    }
    try {
      return processor.process(result, fields);
    } catch (ConfigReportException e) {
      throw e;
    } catch (Exception e) {
      throw new ConfigReportException(
        'Post-processor failed for report ' + definitionName + ': ' + className
      );
    }
  }
}
