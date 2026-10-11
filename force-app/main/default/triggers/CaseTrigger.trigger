trigger CaseTrigger on Case(after update) {
  CaseHandler.dispatch();
}
