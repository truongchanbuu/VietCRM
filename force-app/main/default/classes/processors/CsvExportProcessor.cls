public with sharing class CsvExportProcessor implements IReportPostProcessor {
  public ReportResult process(ReportResult result, List<String> fields) {
    result.csv = toCsv(result.records, fields);
    return result;
  }

  public static String toCsv(List<SObject> records, List<String> fields) {
    List<String> lines = new List<String>();
    List<String> headers = new List<String>();
    for (String field : fields)
      headers.add(escape(field));
    lines.add(String.join(headers, ','));
    for (SObject record : records) {
      List<String> values = new List<String>();
      for (String field : fields)
        values.add(escape(String.valueOf(readPath(record, field))));
      lines.add(String.join(values, ','));
    }
    return String.join(lines, '\r\n');
  }

  private static Object readPath(SObject record, String path) {
    SObject current = record;
    List<String> segments = path.split('\\.');
    for (Integer i = 0; i < segments.size() - 1; i++) {
      if (current == null)
        return null;
      current = current.getSObject(segments[i]);
    }
    return current == null ? null : current.get(segments[segments.size() - 1]);
  }

  private static String escape(String value) {
    String safe = value == null || value == 'null' ? '' : value;
    if (
      safe.contains(',') ||
      safe.contains('"') ||
      safe.contains('\r') ||
      safe.contains('\n')
    ) {
      return '"' + safe.replace('"', '""') + '"';
    }
    return safe;
  }
}
