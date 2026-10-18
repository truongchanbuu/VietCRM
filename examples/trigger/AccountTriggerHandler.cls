/** Opt-in business rules; replace these sample rules with your own. */
public with sharing class AccountTriggerHandler extends AbstractTriggerHandler {
  protected override void beforeInsert(List<SObject> newRecords) {
    List<Account> accounts = (List<Account>) newRecords;
    for (Account account : accounts) {
      account.Name = account.Name?.trim();
    }
    validateNames(accounts);
  }

  protected override void beforeUpdate(
    List<SObject> newRecords,
    Map<Id, SObject> newMap,
    List<SObject> oldRecords,
    Map<Id, SObject> oldMap
  ) {
    Map<Id, Account> previous = (Map<Id, Account>) oldMap;
    for (SObject changed : context.getChangedRecords(Account.Name)) {
      Account account = (Account) changed;
      account.Name = account.Name?.trim();
      account.Description = 'Previous name: ' + previous.get(account.Id).Name;
    }
    validateNames((List<Account>) newRecords);
  }

  private void validateNames(List<Account> accounts) {
    for (Account account : accounts) {
      if (account.Name != null && account.Name.startsWith('REJECT:')) {
        account.addError(
          'Names starting with REJECT: are reserved in this example.'
        );
      }
    }
  }
}
