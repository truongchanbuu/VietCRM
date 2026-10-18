/** Dispatch, native references, no-op defaults, and failure propagation. */
@IsTest
private with sharing class AbstractTriggerHandlerTest {
  @IsTest
  static void beforeInsertDispatchesOnce() {
    assertDispatch(System.TriggerOperation.BEFORE_INSERT);
  }
  @IsTest
  static void beforeUpdateDispatchesOnce() {
    assertDispatch(System.TriggerOperation.BEFORE_UPDATE);
  }
  @IsTest
  static void beforeDeleteDispatchesOnce() {
    assertDispatch(System.TriggerOperation.BEFORE_DELETE);
  }
  @IsTest
  static void afterInsertDispatchesOnce() {
    assertDispatch(System.TriggerOperation.AFTER_INSERT);
  }
  @IsTest
  static void afterUpdateDispatchesOnce() {
    assertDispatch(System.TriggerOperation.AFTER_UPDATE);
  }
  @IsTest
  static void afterDeleteDispatchesOnce() {
    assertDispatch(System.TriggerOperation.AFTER_DELETE);
  }
  @IsTest
  static void afterUndeleteDispatchesOnce() {
    assertDispatch(System.TriggerOperation.AFTER_UNDELETE);
  }

  private static void assertDispatch(System.TriggerOperation operation) {
    TriggerContext invocation = TriggerTestDataFactory.invocation(operation);
    RecordingHandler handler = new RecordingHandler();
    Test.startTest();
    handler.dispatch(invocation);
    Test.stopTest();
    Assert.areEqual(
      new List<System.TriggerOperation>{ operation },
      handler.calls,
      'Only the matching callback must run'
    );
    Assert.isTrue(
      invocation === handler.seenContext,
      'Expose this invocation to subclasses'
    );
  }

  @IsTest
  static void defaultCallbacksAreNoOpsWithoutDatabaseWork() {
    AbstractTriggerHandler handler = new EmptyHandler();
    Test.startTest();
    Integer queries = Limits.getQueries();
    Integer dml = Limits.getDmlStatements();
    for (System.TriggerOperation operation : System.TriggerOperation.values()) {
      TriggerContext invocation = TriggerTestDataFactory.invocation(operation);
      handler.dispatch(invocation);
    }
    Assert.areEqual(
      queries,
      Limits.getQueries(),
      'Toolkit must perform no SOQL'
    );
    Assert.areEqual(
      dml,
      Limits.getDmlStatements(),
      'Toolkit must perform no DML'
    );
    Test.stopTest();
  }

  @IsTest
  static void repeatedInvocationsAreNotSuppressed() {
    RecordingHandler handler = new RecordingHandler();
    TriggerContext first = TriggerTestDataFactory.invocation(
      System.TriggerOperation.BEFORE_UPDATE
    );
    TriggerContext second = TriggerTestDataFactory.invocation(
      System.TriggerOperation.BEFORE_UPDATE
    );
    Test.startTest();
    handler.dispatch(first);
    handler.dispatch(second);
    Test.stopTest();
    Assert.areEqual(
      2,
      handler.calls.size(),
      'Every invocation must dispatch fully'
    );
    Assert.isTrue(
      second === handler.seenContext,
      'Replace context for every invocation'
    );
  }

  @IsTest
  static void runOutsideTriggerFailsClearly() {
    Test.startTest();
    try {
      new EmptyHandler().run();
      Assert.fail('Expected active-trigger requirement');
    } catch (TriggerToolkitException failure) {
      Assert.isTrue(
        failure.getMessage().contains('active trigger execution'),
        'Explain execution requirement'
      );
    }
    Test.stopTest();
  }

  @IsTest
  static void handlerFailurePropagatesUnchanged() {
    FailingHandler handler = new FailingHandler();
    Test.startTest();
    try {
      handler.dispatch(
        TriggerTestDataFactory.invocation(System.TriggerOperation.BEFORE_INSERT)
      );
      Assert.fail('Expected original failure');
    } catch (TriggerToolkitException failure) {
      Assert.isTrue(failure === handler.failure, 'Retain exception identity');
    }
    Test.stopTest();
  }

  private with sharing class EmptyHandler extends AbstractTriggerHandler {
  }

  private with sharing class FailingHandler extends AbstractTriggerHandler {
    TriggerToolkitException failure = new TriggerToolkitException(
      'Business failure'
    );
    protected override void beforeInsert(List<SObject> records) {
      throw failure;
    }
  }

  private with sharing class RecordingHandler extends AbstractTriggerHandler {
    List<System.TriggerOperation> calls = new List<System.TriggerOperation>();
    TriggerContext seenContext;
    private void recordCall(System.TriggerOperation operation) {
      calls.add(operation);
      seenContext = context;
    }
    protected override void beforeInsert(List<SObject> newRecords) {
      recordCall(System.TriggerOperation.BEFORE_INSERT);
      Assert.isTrue(
        newRecords === context.getNewRecords(),
        'Forward native newRecords'
      );
    }
    protected override void beforeUpdate(
      List<SObject> newRecords,
      Map<Id, SObject> newMap,
      List<SObject> oldRecords,
      Map<Id, SObject> oldMap
    ) {
      recordCall(System.TriggerOperation.BEFORE_UPDATE);
      Assert.isTrue(
        newRecords === context.getNewRecords(),
        'Forward native newRecords'
      );
      Assert.isTrue(newMap === context.getNewMap(), 'Forward native newMap');
      Assert.isTrue(
        oldRecords === context.getOldRecords(),
        'Forward native oldRecords'
      );
      Assert.isTrue(oldMap === context.getOldMap(), 'Forward native oldMap');
    }
    protected override void beforeDelete(
      List<SObject> oldRecords,
      Map<Id, SObject> oldMap
    ) {
      recordCall(System.TriggerOperation.BEFORE_DELETE);
      Assert.isTrue(
        oldRecords === context.getOldRecords(),
        'Forward native oldRecords'
      );
      Assert.isTrue(oldMap === context.getOldMap(), 'Forward native oldMap');
    }
    protected override void afterInsert(
      List<SObject> newRecords,
      Map<Id, SObject> newMap
    ) {
      recordCall(System.TriggerOperation.AFTER_INSERT);
      Assert.isTrue(
        newRecords === context.getNewRecords(),
        'Forward native newRecords'
      );
      Assert.isTrue(newMap === context.getNewMap(), 'Forward native newMap');
    }
    protected override void afterUpdate(
      List<SObject> newRecords,
      Map<Id, SObject> newMap,
      List<SObject> oldRecords,
      Map<Id, SObject> oldMap
    ) {
      recordCall(System.TriggerOperation.AFTER_UPDATE);
      Assert.isTrue(
        newRecords === context.getNewRecords(),
        'Forward native newRecords'
      );
      Assert.isTrue(newMap === context.getNewMap(), 'Forward native newMap');
      Assert.isTrue(
        oldRecords === context.getOldRecords(),
        'Forward native oldRecords'
      );
      Assert.isTrue(oldMap === context.getOldMap(), 'Forward native oldMap');
    }
    protected override void afterDelete(
      List<SObject> oldRecords,
      Map<Id, SObject> oldMap
    ) {
      recordCall(System.TriggerOperation.AFTER_DELETE);
      Assert.isTrue(
        oldRecords === context.getOldRecords(),
        'Forward native oldRecords'
      );
      Assert.isTrue(oldMap === context.getOldMap(), 'Forward native oldMap');
    }
    protected override void afterUndelete(
      List<SObject> newRecords,
      Map<Id, SObject> newMap
    ) {
      recordCall(System.TriggerOperation.AFTER_UNDELETE);
      Assert.isTrue(
        newRecords === context.getNewRecords(),
        'Forward native newRecords'
      );
      Assert.isTrue(newMap === context.getNewMap(), 'Forward native newMap');
    }
  }
}
