/** Real DML against the opt-in Account example, deployed only for validation. */
@IsTest
private with sharing class AccountTriggerIntegrationTest {
  private static List<Account> accounts() {
    List<Account> records = new List<Account>();
    for (Integer i = 0; i < 251; i++) {
      records.add(new Account(Name = '  Toolkit ' + i + '  '));
    }
    return records;
  }

  @IsTest
  static void bulkLifecycleAndRepeatedUpdates() {
    List<Account> records = accounts();
    Test.startTest();
    insert as user records;
    Set<Id> ids = new Map<Id, Account>(records).keySet();
    List<Account> stored = [
      SELECT Id, Name, Description
      FROM Account
      WHERE Id IN :ids
      WITH USER_MODE
    ];
    Assert.areEqual(
      records.size(),
      stored.size(),
      'Insert every record across both batches'
    );
    for (Account account : stored) {
      Assert.areEqual(
        account.Name.trim(),
        account.Name,
        'Before insert edits must persist'
      );
      account.Name = 'First ' + account.Name;
    }
    update as user stored;
    for (Account account : stored) {
      account.Name = 'Second ' + account.Name;
    }
    update as user stored;
    List<Account> updated = [
      SELECT Id, Name, Description
      FROM Account
      WHERE Id IN :ids
      WITH USER_MODE
    ];
    for (Account account : updated) {
      Assert.areEqual(
        'Previous name: ' + account.Name.substring('Second '.length()),
        account.Description,
        'Repeated updates must use the latest old map for every record'
      );
    }
    delete as user updated;
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Account WHERE Id IN :ids WITH USER_MODE],
      'Delete all records'
    );
    // Apex undelete has no user-mode keyword; this test-only operation restores its own fixtures.
    undelete updated;
    Assert.areEqual(
      records.size(),
      [SELECT COUNT() FROM Account WHERE Id IN :ids WITH USER_MODE],
      'Undelete all records'
    );
    Test.stopTest();
  }

  @IsTest
  static void unchangedNameLeavesDescriptionAlone() {
    Account account = new Account(Name = 'Stable', Description = 'Keep');
    insert as user account;
    account.Phone = '123';
    Test.startTest();
    update as user account;
    Test.stopTest();
    Assert.areEqual(
      'Keep',
      [SELECT Description FROM Account WHERE Id = :account.Id WITH USER_MODE]
      .Description,
      'Unchanged names must not invoke name-change rules'
    );
  }

  @IsTest
  static void partialInsertRetainsNativeErrors() {
    List<Account> records = accounts();
    records[0].Name = 'REJECT: invalid';
    Test.startTest();
    List<Database.SaveResult> results = Database.insert(
      records,
      false,
      AccessLevel.USER_MODE
    );
    Test.stopTest();
    Assert.isFalse(
      results[0].isSuccess(),
      'addError must reject its original trigger record'
    );
    Assert.areEqual(
      'Names starting with REJECT: are reserved in this example.',
      results[0].getErrors()[0].getMessage(),
      'Keep business validation message'
    );
    for (Integer i = 1; i < records.size(); i++) {
      Assert.isTrue(
        results[i].isSuccess(),
        'Partial-success retries must process every valid record'
      );
    }
    Assert.areEqual(
      records.size() - 1,
      [SELECT COUNT() FROM Account WHERE Id IN :records WITH USER_MODE],
      'Only the invalid record must fail'
    );
  }

  @IsTest
  static void partialUpdateRetainsNativeErrors() {
    List<Account> records = accounts();
    insert as user records;
    for (Account account : records) {
      account.Name = 'Updated ' + account.Name;
    }
    records[0].Name = 'REJECT: invalid';
    Test.startTest();
    List<Database.SaveResult> results = Database.update(
      records,
      false,
      AccessLevel.USER_MODE
    );
    Test.stopTest();
    Assert.isFalse(results[0].isSuccess(), 'Reject the invalid update');
    for (Integer i = 1; i < records.size(); i++) {
      Assert.isTrue(results[i].isSuccess(), 'All valid updates survive retry');
    }
    Assert.areEqual(
      'Toolkit 0',
      [SELECT Name FROM Account WHERE Id = :records[0].Id WITH USER_MODE].Name,
      'Invalid update must roll back its before-trigger changes'
    );
  }
}
