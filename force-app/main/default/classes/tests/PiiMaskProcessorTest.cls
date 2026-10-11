@IsTest
private class PiiMaskProcessorTest {
  @IsTest
  static void maskingFlagAndPermissionControlClearText() {
    User viewer = makeUser();
    User restricted = makeUser();
    restricted.Username = 'crnopii' + System.now().getTime() + '@example.com';
    restricted.Alias = 'crno';
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

    System.runAs(viewer) {
      assertEmail(true, 'a***@example.com');
      assertEmail(false, 'alice@example.com');
    }
    System.runAs(restricted) {
      assertCurrentUserEmail(true, 'a***@example.com');
      assertCurrentUserEmail(false, 'a***@example.com');
    }
  }

  private static void assertCurrentUserEmail(
    Boolean maskingEnabled,
    String expected
  ) {
    CaseFeatureFlags.overrides.put('piimasking', maskingEnabled);
    ReportResult result = new ReportResult();
    result.records.add(new Contact(Email = 'alice@example.com'));
    new PiiMaskProcessor().process(result, new List<String>{ 'Email' });
    System.assertEquals(expected, result.records[0].get('Email'));
  }

  private static void assertEmail(Boolean maskingEnabled, String expected) {
    CaseFeatureFlags.overrides.put('piimasking', maskingEnabled);
    ReportResult result = new ReportResult();
    result.records.add(
      new Contact(Email = 'alice@example.com', Phone = '0912345689')
    );
    new PiiMaskProcessor()
      .process(result, new List<String>{ 'Email', 'Phone' });
    System.assertEquals(expected, result.records[0].get('Email'));
    System.assertEquals('09******89', result.records[0].get('Phone'));
  }

  private static User makeUser() {
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
      LastName = 'PII Viewer',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = 'crpii' + System.now().getTime() + '@example.com',
      ProfileId = profile.Id
    );
  }
}
