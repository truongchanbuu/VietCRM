@IsTest
private class GenericSelectorTest {
  @TestSetup
  static void setupRecords() {
    Account account = TestDataFactory.accountRecord('VIP');
    insert account;
    insert new Contact(
      LastName = 'Config Contact',
      AccountId = account.Id,
      Email = 'person@example.com',
      Phone = '0912345678'
    );
    insert new List<Case>{
      TestDataFactory.caseRecord(account.Id, 'Alpha'),
      TestDataFactory.caseRecord(account.Id, 'Beta')
    };
  }

  @IsTest
  static void queriesCasesAccountsAndContactsWithBinds() {
    ReportResult cases = GenericSelector.execute(
      request('Case', new List<String>{ 'Id', 'Subject' }, null),
      20
    );
    ReportResult accounts = GenericSelector.execute(
      request('Account', new List<String>{ 'Id', 'Name' }, null),
      20
    );
    ReportResult contacts = GenericSelector.execute(
      request('Contact', new List<String>{ 'Id', 'Email' }, null),
      20
    );
    System.assertEquals(2, cases.records.size());
    System.assertEquals('Alpha', cases.records[0].get('Subject'));
    System.assertEquals(1, accounts.records.size());
    System.assertEquals(
      'ConfigReport Test Account',
      accounts.records[0].get('Name')
    );
    System.assertEquals(1, contacts.records.size());
    System.assertEquals('person@example.com', contacts.records[0].get('Email'));
    System.assertEquals(1, cases.bindCount, 'LIMIT is a bind value too.');
    System.assert(
      cases.soql.contains('LIMIT :b0'),
      'SOQL exposes only a generated bind placeholder.'
    );
  }

  @IsTest
  static void appliesServiceRowCapAndRefactoredCaseSelector() {
    ReportRequest capped = request('Case', new List<String>{ 'Id' }, null);
    capped.limitSize = 5000;
    ReportResult result = GenericSelector.execute(capped, 1);
    System.assertEquals(1, result.records.size());
    System.assertEquals(
      true,
      result.truncated,
      'A maxRows cap lower than the request is reported.'
    );

    List<Case> page = CaseSelector.getCasesPaged(10, 0);
    System.assertEquals(
      2,
      page.size(),
      'Legacy CaseSelector method delegates through GenericSelector.'
    );
  }

  @IsTest
  static void supportsThreeLevelRelationshipAndCsv() {
    ReportResult result = GenericSelector.execute(
      request('Case', new List<String>{ 'Id', 'Account.Owner.Name' }, null),
      20
    );
    String csv = CsvExportProcessor.toCsv(
      result.records,
      new List<String>{ 'Account.Owner.Name' }
    );
    System.assert(
      csv.contains(UserInfo.getName()),
      'Relationship path is traversed for CSV output.'
    );
  }

  @IsTest
  static void bindsInjectionPayloadAsLiteralValue() {
    ReportResult result = GenericSelector.execute(
      request(
        'Case',
        new List<String>{ 'Id' },
        new List<FilterCondition>{
          new FilterCondition('Subject', '=', 'x\' OR Name != \'')
        }
      ),
      20
    );
    System.assertEquals(0, result.records.size());
    System.assert(
      !result.soql.contains('x\' OR Name'),
      'Payload must never appear in SOQL text.'
    );
    System.assertEquals(
      2,
      result.bindCount,
      'Filter and LIMIT values are both bound.'
    );
  }

  @IsTest
  static void rejectsUnsafeFieldsOperatorsAndTypes() {
    assertInvalid(
      request('Case', new List<String>{ 'Id FROM Account --' }, null),
      'field injection'
    );
    assertInvalid(
      request(
        'Case',
        new List<String>{ 'Id' },
        new List<FilterCondition>{
          new FilterCondition('Status', '; DELETE', 'New')
        }
      ),
      'operator injection'
    );
    assertInvalid(
      request(
        'Case',
        new List<String>{ 'Id' },
        new List<FilterCondition>{
          new FilterCondition('CreatedDate', 'LIKE', '%2026%')
        }
      ),
      'LIKE on DateTime'
    );
  }

  @IsTest
  static void schemaDescribeIsCachedOnce() {
    SchemaHelper.resetCache();
    for (Integer i = 0; i < 50; i++) {
      System.assertNotEquals(null, SchemaHelper.getSObjectType('case'));
      System.assert(
        SchemaHelper.getAccessibleFields('Case').contains('Subject')
      );
    }
    System.assertEquals(
      1,
      SchemaHelper.globalDescribeCalls,
      'Global describe is loaded once per transaction.'
    );
  }

  @IsTest
  static void rejectsFieldWithoutReadAccess() {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    User lowPrivilege = new User(
      Alias = 'crlow',
      Email = 'crlow@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Low Privilege',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'crlow' + System.now().getTime() + '@example.com',
      ProfileId = standardProfile.Id
    );
    insert lowPrivilege;
    System.runAs(lowPrivilege) {
      try {
        GenericSelector.execute(
          request('Account', new List<String>{ 'Id', 'Tier__c' }, null),
          10
        );
        System.assert(false, 'A field without FLS must be rejected.');
      } catch (ConfigReportException expected) {
        System.assert(expected.getMessage().contains('Tier__c'));
      }
    }
  }

  private static ReportRequest request(
    String objectName,
    List<String> fields,
    List<FilterCondition> filters
  ) {
    ReportRequest value = new ReportRequest();
    value.objectName = objectName;
    value.fields = fields;
    value.filters = filters;
    value.orderBy = 'Id';
    value.limitSize = 20;
    return value;
  }

  private static void assertInvalid(ReportRequest requestValue, String label) {
    try {
      GenericSelector.execute(requestValue, 20);
      System.assert(false, 'Expected ConfigReportException: ' + label);
    } catch (ConfigReportException expected) {
      System.assert(
        !String.isBlank(expected.getMessage()),
        'Exception should explain ' + label
      );
    }
  }
}
