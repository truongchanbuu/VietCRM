public with sharing class ReportDefinitionDomain {
  public static List<String> validate(Report_Definition__mdt definition) {
    List<String> errors = new List<String>();
    if (definition == null)
      return new List<String>{ 'Report definition was not found.' };
    String name = definition.DeveloperName;
    if (definition.Is_Active__c != true)
      errors.add('Report ' + name + ' is inactive.');
    if (String.isBlank(definition.Object_Name__c))
      errors.add('Report ' + name + ' has no object name.');
    if (String.isBlank(definition.Fields__c)) {
      errors.add('Report ' + name + ' has no SELECT fields.');
    } else {
      List<String> fields = definition.Fields__c.split(',');
      Set<String> seen = new Set<String>();
      if (fields.size() > 30)
        errors.add('Report ' + name + ' has more than 30 fields.');
      for (String field : fields) {
        String normalized = field.trim().toLowerCase();
        if (String.isBlank(normalized)) {
          errors.add('Report ' + name + ' contains an empty field name.');
        } else if (!seen.add(normalized)) {
          errors.add('Report ' + name + ' repeats field ' + field.trim() + '.');
        }
      }
    }
    if (
      definition.Default_Limit__c == null ||
      definition.Default_Limit__c <= 0
    ) {
      errors.add(
        'Report ' + name + ' must have Default_Limit__c greater than zero.'
      );
    }
    return errors;
  }
}
