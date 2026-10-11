trigger LogEventTrigger on LogEvent__e(after insert) {
  LogEventHandler.dispatch();
}
