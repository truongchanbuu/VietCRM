public interface IReportPostProcessor {
  ReportResult process(ReportResult result, List<String> fields);
}
