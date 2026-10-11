public with sharing class CaseService {
  public static void escalateCriticalCases(List<Case> casesToEscalate) {
    List<Case> updates = new List<Case>();
    for (Case caseRecord : casesToEscalate) {
      if (caseRecord.Id == null)
        throw new ConfigReportException(
          'Cannot escalate a Case without an Id.'
        );
      if (caseRecord.Status != 'Escalated')
        updates.add(new Case(Id = caseRecord.Id, Status = 'Escalated'));
    }

    if (!updates.isEmpty())
      update updates;
  }

  public static void afterUpdate(List<Case> newCases, Map<Id, Case> oldCases) {
    if (!CaseFeatureFlags.isEnabled('ConfigReport'))
      return;
    List<Case> escalated = new List<Case>();
    Set<Id> accountIds = new Set<Id>();
    for (Case currentCase : newCases) {
      Case oldCase = oldCases.get(currentCase.Id);
      if (
        oldCase != null &&
        oldCase.Status != 'Escalated' &&
        currentCase.Status == 'Escalated'
      ) {
        escalated.add(currentCase);
        if (currentCase.AccountId != null)
          accountIds.add(currentCase.AccountId);
      }
    }
    if (escalated.isEmpty())
      return;

    Report_Definition__mdt definition = ConfigReportService.getDefinition(
      'Open_Cases'
    );

    List<String> fields = new List<String>();
    for (String value : definition.Fields__c.split(','))
      fields.add(value.trim());

    Map<Id, String> csvByAccount = new Map<Id, String>();
    if (!accountIds.isEmpty()) {
      List<Object> accountFilterValues = new List<Object>();

      for (Id accountId : accountIds)
        accountFilterValues.add(accountId);

      ReportResult report = ConfigReportService.run(
        'Open_Cases',
        new List<FilterCondition>{
          new FilterCondition('AccountId', 'IN', accountFilterValues)
        }
      );

      Map<Id, List<SObject>> recordsByAccount = new Map<Id, List<SObject>>();
      for (SObject row : report.records) {
        Id accountId = (Id) row.get('AccountId');
        if (!recordsByAccount.containsKey(accountId))
          recordsByAccount.put(accountId, new List<SObject>());
        recordsByAccount.get(accountId).add(row);
      }

      for (Id accountId : accountIds) {
        csvByAccount.put(
          accountId,
          CsvExportProcessor.toCsv(
            recordsByAccount.containsKey(accountId)
              ? recordsByAccount.get(accountId)
              : new List<SObject>(),
            fields
          )
        );
      }
    }

    List<CriticalCase__e> events = new List<CriticalCase__e>();
    for (Case caseRecord : escalated) {
      String csv = caseRecord.AccountId == null
        ? CsvExportProcessor.toCsv(new List<SObject>(), fields)
        : csvByAccount.get(caseRecord.AccountId);
      if (csv != null && csv.length() > 32768) {
        throw new ConfigReportException(
          'Open_Cases CSV exceeds CriticalCase__e.OpenCasesCsv__c capacity for Account ' +
            caseRecord.AccountId +
            '.'
        );
      }
      events.add(
        new CriticalCase__e(CaseId__c = caseRecord.Id, OpenCasesCsv__c = csv)
      );
    }

    List<Database.SaveResult> publishResults = EventBus.publish(events);
    for (Integer i = 0; i < publishResults.size(); i++) {
      if (!publishResults[i].isSuccess()) {
        System.debug(
          LoggingLevel.ERROR,
          'CriticalCase event rejected for Case ' +
            escalated[i].Id +
            ': ' +
            publishResults[i].getErrors()[0].getStatusCode()
        );
      }
    }
  }
}
