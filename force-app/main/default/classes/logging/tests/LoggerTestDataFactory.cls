/** Test-only events and users; adapt the schema alongside the logger. */
@IsTest
public with sharing class LoggerTestDataFactory {
  /**
   * Builds a valid unsaved event, including an initialized event UUID.
   * @param message Exact expected test message.
   * @return A sample log event.
   */
  public static LogEvent__e eventRecord(String message) {
    LogEvent__e eventRecord = (LogEvent__e) LogEvent__e.SObjectType.newSObject(
      null,
      true
    );
    eventRecord.Level__c = 'INFO';
    eventRecord.Message__c = message;
    eventRecord.Source__c = 'LoggerTemplateTest';
    eventRecord.TransactionId__c = Request.getCurrent().getRequestId();
    eventRecord.UserId__c = UserInfo.getUserId();
    eventRecord.OccurredAt__c = System.now();
    eventRecord.Operation__c = 'UNIT_TEST';
    eventRecord.RecordId__c = UserInfo.getUserId();
    eventRecord.Status__c = 'New';
    return eventRecord;
  }

  /**
   * Creates a minimum-access user with an isolated test-only permission grant.
   * @param permissionName LoggerPublish, LoggerRead, LoggerReadLimited, or null for no grant.
   * @return Inserted user, usable with System.runAs.
   */
  public static User createUser(String permissionName) {
    Profile minimum = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      WITH SYSTEM_MODE
      LIMIT 1
    ];
    String uniqueName = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    User userRecord = new User(
      Alias = 'logtest',
      Email = 'logger@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Logger Template',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = minimum.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = uniqueName + '@logger.example.invalid'
    );
    // Test fixture setup requires administrative access, independent of the test user's permissions.
    insert as system userRecord;
    if (permissionName != null) {
      PermissionSet permission = createPermission(permissionName, uniqueName);
      insert as system new PermissionSetAssignment(
        AssigneeId = userRecord.Id,
        PermissionSetId = permission.Id
      );
    }
    return userRecord;
  }

  private static PermissionSet createPermission(
    String permissionName,
    String uniqueName
  ) {
    PermissionSet permission = new PermissionSet(
      Name = 'LoggerTest' + uniqueName.left(12),
      Label = 'Logger test grant'
    );
    insert as system permission;
    Boolean publish = permissionName == 'LoggerPublish';
    String objectName = publish ? 'LogEvent__e' : 'Log__c';
    insert as system new ObjectPermissions(
      ParentId = permission.Id,
      SObjectType = objectName,
      PermissionsRead = true,
      PermissionsCreate = publish,
      PermissionsViewAllRecords = !publish
    );
    if (publish) {
      return permission;
    }
    Schema.SObjectType objectType = Log__c.SObjectType;
    List<FieldPermissions> fields = new List<FieldPermissions>();
    for (
      Schema.SObjectField field : objectType.getDescribe(
          SObjectDescribeOptions.DEFERRED
        )
        .fields.getMap()
        .values()
    ) {
      Schema.DescribeFieldResult description = field.getDescribe();
      Boolean omittedMessage =
        permissionName == 'LoggerReadLimited' &&
        description.getName() == 'Message__c';
      if (
        description.isCustom() &&
        description.isPermissionable() &&
        !omittedMessage
      ) {
        fields.add(
          new FieldPermissions(
            ParentId = permission.Id,
            SObjectType = objectName,
            Field = objectName + '.' + description.getName(),
            PermissionsRead = true,
            PermissionsEdit = publish
          )
        );
      }
    }
    insert as system fields;
    return permission;
  }

  /**
   * Models an immediate platform result without relying on nondeterministic failures.
   * @param code Status code, or null for success.
   * @param fields Fields associated with the failure.
   * @return A platform-shaped result for boundary tests.
   */
  public static Database.SaveResult result(String code, List<String> fields) {
    Map<String, Object> value = new Map<String, Object>{
      'success' => code == null,
      'errors' => code == null
        ? new List<Object>()
        : new List<Object>{
            new Map<String, Object>{
              'statusCode' => code,
              'fields' => fields,
              'message' => 'PRIVATE_PAYLOAD'
            }
          }
    };
    return (Database.SaveResult) JSON.deserialize(
      JSON.serialize(value),
      Database.SaveResult.class
    );
  }
}
