public with sharing class GenericSelector {
  private static final Set<String> OPERATORS = new Set<String>{
    '=',
    '!=',
    '>',
    '<',
    '>=',
    '<=',
    'LIKE',
    'IN',
    'NOT IN'
  };

  public static ReportResult execute(ReportRequest request, Integer maxRows) {
    validateRequest(request, maxRows);
    Schema.SObjectType objectType = SchemaHelper.getSObjectType(
      request.objectName
    );
    String objectName = objectType.getDescribe().getName();
    List<String> selectFields = new List<String>();
    Set<String> seen = new Set<String>();
    for (String field : request.fields) {
      String normalized = SchemaHelper.normalizeFieldPath(objectName, field);
      if (!seen.add(normalized.toLowerCase())) {
        throw new ConfigReportException('Duplicate selected field: ' + field);
      }
      selectFields.add(normalized);
    }

    Integer desiredLimit = request.limitSize == null ||
      request.limitSize <= 0
      ? 100
      : request.limitSize;
    Integer rowLimit = Math.min(desiredLimit, maxRows);
    Integer availableRows = Limits.getLimitQueryRows() - Limits.getQueryRows();
    if (availableRows <= 0)
      throw new ConfigReportException(
        'No query-row budget remains for report ' + objectName + '.'
      );
    Integer fetchLimit = Math.min(rowLimit + 1, availableRows);

    Map<String, Object> binds = new Map<String, Object>();
    List<String> whereParts = new List<String>();
    Integer bindIndex = 0;
    for (
      FilterCondition condition : request.filters == null
        ? new List<FilterCondition>()
        : request.filters
    ) {
      if (condition == null)
        throw new ConfigReportException('Filter cannot be null.');
      Schema.DescribeFieldResult fieldDescribe = SchemaHelper.resolveFieldPath(
        objectName,
        condition.field
      );
      if (!fieldDescribe.isFilterable())
        throw new ConfigReportException(
          'Field is not filterable: ' + condition.field
        );
      String operator = condition.operator == null
        ? ''
        : condition.operator.trim().toUpperCase();
      if (!OPERATORS.contains(operator))
        throw new ConfigReportException(
          'Unsupported operator for ' +
            condition.field +
            ': ' +
            condition.operator
        );
      validateOperator(condition.field, operator, fieldDescribe.getType());
      String bindName = 'b' + bindIndex++;
      whereParts.add(
        SchemaHelper.normalizeFieldPath(objectName, condition.field) +
          ' ' +
          operator +
          ' :' +
          bindName
      );
      binds.put(
        bindName,
        coerceValue(
          condition.value,
          fieldDescribe.getType(),
          condition.field,
          operator
        )
      );
    }

    String soql =
      'SELECT ' +
      String.join(selectFields, ', ') +
      ' FROM ' +
      objectName;
    if (!whereParts.isEmpty())
      soql += ' WHERE ' + String.join(whereParts, ' AND ');
    if (!String.isBlank(request.orderBy)) {
      String orderField = SchemaHelper.normalizeFieldPath(
        objectName,
        request.orderBy
      );
      if (!SchemaHelper.isSortable(objectName, request.orderBy))
        throw new ConfigReportException(
          'Field is not sortable: ' + request.orderBy
        );
      soql +=
        ' ORDER BY ' +
        orderField +
        (request.orderDesc == true ? ' DESC' : ' ASC');
    }
    String limitBind = 'b' + bindIndex++;
    soql += ' LIMIT :' + limitBind;
    binds.put(limitBind, fetchLimit);
    if (request.offsetSize != null && request.offsetSize > 0) {
      if (request.offsetSize > 2000)
        throw new ConfigReportException(
          'Offset exceeds the Salesforce maximum of 2000.'
        );
      String offsetBind = 'b' + bindIndex++;
      soql += ' OFFSET :' + offsetBind;
      binds.put(offsetBind, request.offsetSize);
    }

    List<SObject> fetched;
    try {
      fetched = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);
    } catch (QueryException e) {
      throw new ConfigReportException(
        'User-mode report query failed for ' +
          objectName +
          ': ' +
          e.getMessage()
      );
    }
    Boolean truncated =
      fetched.size() > rowLimit ||
      (fetchLimit <= rowLimit &&
      rowLimit + 1 > availableRows);
    while (fetched.size() > rowLimit)
      fetched.remove(fetched.size() - 1);
    ReportResult result = new ReportResult();
    result.records = fetched;
    result.soql = soql;
    result.bindCount = bindIndex;
    result.truncated = truncated;
    return result;
  }

  private static void validateRequest(ReportRequest request, Integer maxRows) {
    if (request == null)
      throw new ConfigReportException('Report request is required.');
    if (String.isBlank(request.objectName))
      throw new ConfigReportException('Object name is required.');
    if (request.fields == null || request.fields.isEmpty())
      throw new ConfigReportException('At least one SELECT field is required.');
    if (maxRows == null || maxRows <= 0)
      throw new ConfigReportException('maxRows must be positive.');
  }

  private static void validateOperator(
    String path,
    String operator,
    Schema.DisplayType type
  ) {
    if (
      operator == 'LIKE' &&
      !new Set<Schema.DisplayType>{
          Schema.DisplayType.STRING,
          Schema.DisplayType.PICKLIST,
          Schema.DisplayType.EMAIL,
          Schema.DisplayType.PHONE
        }
        .contains(type)
    ) {
      throw new ConfigReportException(
        'LIKE is not supported for field ' + path + ' (' + type + ').'
      );
    }
    if (
      new Set<String>{ '>', '<', '>=', '<=' }.contains(operator) &&
      !new Set<Schema.DisplayType>{
          Schema.DisplayType.INTEGER,
          Schema.DisplayType.DOUBLE,
          Schema.DisplayType.CURRENCY,
          Schema.DisplayType.PERCENT,
          Schema.DisplayType.DATE,
          Schema.DisplayType.DATETIME
        }
        .contains(type)
    ) {
      throw new ConfigReportException(
        'Comparison operator ' +
          operator +
          ' is not supported for field ' +
          path +
          ' (' +
          type +
          ').'
      );
    }
  }

  private static Object coerceValue(
    Object value,
    Schema.DisplayType type,
    String path,
    String operator
  ) {
    if (operator == 'IN' || operator == 'NOT IN') {
      if (!(value instanceof List<Object>))
        throw new ConfigReportException(
          operator + ' requires a list value for ' + path + '.'
        );
      List<Object> converted = new List<Object>();
      for (Object item : (List<Object>) value)
        converted.add(coerceScalar(item, type, path));
      return converted;
    }
    return coerceScalar(value, type, path);
  }

  private static Object coerceScalar(
    Object value,
    Schema.DisplayType type,
    String path
  ) {
    if (value == null)
      return null;
    try {
      if (type == Schema.DisplayType.DATE)
        return value instanceof Date
          ? value
          : Date.valueOf(String.valueOf(value));
      if (type == Schema.DisplayType.DATETIME)
        return value instanceof Datetime
          ? value
          : Datetime.valueOf(String.valueOf(value));
      if (
        new Set<Schema.DisplayType>{
            Schema.DisplayType.INTEGER,
            Schema.DisplayType.DOUBLE,
            Schema.DisplayType.CURRENCY,
            Schema.DisplayType.PERCENT
          }
          .contains(type)
      ) {
        return Decimal.valueOf(String.valueOf(value));
      }
      if (type == Schema.DisplayType.BOOLEAN) {
        if (value instanceof Boolean)
          return value;
        String boolValue = String.valueOf(value).toLowerCase();
        if (boolValue != 'true' && boolValue != 'false')
          throw new TypeException('Expected true/false.');
        return boolValue == 'true';
      }
      if (type == Schema.DisplayType.REFERENCE) {
        if (value instanceof Id)
          return value;
        return Id.valueOf(String.valueOf(value));
      }
      if (
        type == Schema.DisplayType.STRING ||
        type == Schema.DisplayType.TEXTAREA ||
        type == Schema.DisplayType.PICKLIST ||
        type == Schema.DisplayType.EMAIL ||
        type == Schema.DisplayType.PHONE ||
        type == Schema.DisplayType.URL ||
        type == Schema.DisplayType.ENCRYPTEDSTRING
      )
        return String.valueOf(value);
      if (
        !(value instanceof String) &&
        !(value instanceof Date) &&
        !(value instanceof Number)
      ) {
        throw new TypeException(
          'Unsupported value type ' + String.valueOf(value.getClass())
        );
      }
      return value;
    } catch (Exception e) {
      throw new ConfigReportException(
        'Invalid value for field ' +
          path +
          ' (' +
          type +
          '): ' +
          String.valueOf(value)
      );
    }
  }
}
