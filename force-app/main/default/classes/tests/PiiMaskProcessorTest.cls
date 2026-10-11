@IsTest
private class PiiMaskProcessorTest {
  @IsTest
  static void respectsPermissionAndConfiguredMaskingFlag() {
    User viewer = makeUser('viewer');
    User restricted = makeUser('restricted');
    insert new List<User>{ viewer, restricted };
    PermissionSet piiPermission = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'ViewPII'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = viewer.Id,
      PermissionSetId = piiPermission.Id
    );
    FeatureFlag__mdt flag = FeatureFlag__mdt.getInstance('PiiMasking');
    Boolean maskingEnabled = flag != null && flag.IsEnabled__c == true;
    System.runAs(viewer) {
      System.assertEquals(true, FeatureManagement.checkPermission('View_PII'));
      assertValues(
        maskingEnabled ? 'a***@example.com' : 'alice@example.com',
        maskingEnabled ? '09******89' : '0912345689'
      );
    }
    System.runAs(restricted) {
      System.assertEquals(false, FeatureManagement.checkPermission('View_PII'));
      assertValues('a***@example.com', '09******89');
    }
  }

  private static void assertValues(String expectedEmail, String expectedPhone) {
    ReportResult result = new ReportResult();
    result.records.add(
      new Contact(Email = 'alice@example.com', Phone = '0912345689')
    );
    new PiiMaskProcessor()
      .process(result, new List<String>{ 'Email', 'Phone' });
    System.assertEquals(expectedEmail, result.records[0].get('Email'));
    System.assertEquals(expectedPhone, result.records[0].get('Phone'));
  }

  private static User makeUser(String suffix) {
    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    return new User(
      Alias = 'crpii',
      Email = 'crpii@example.com',
      EmailEncodingKey = 'UTF-8',
      LastName = suffix,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'crpii.' +
        suffix +
        '.' +
        UserInfo.getOrganizationId() +
        '.' +
        System.now().getTime() +
        '@example.com',
      ProfileId = profile.Id
    );
  }
}
