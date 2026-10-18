/** Test records shared by query module tests; no dependency on business modules. */
@IsTest
public with sharing class QueryTestDataFactory {
  public static void createPageAccounts() {
    insert new List<Account>{
      new Account(Name = 'Page A'),
      new Account(Name = 'Page B'),
      new Account(Name = 'Page C'),
      new Account(Name = 'Page D'),
      new Account(Name = 'Page E')
    };
  }
}
