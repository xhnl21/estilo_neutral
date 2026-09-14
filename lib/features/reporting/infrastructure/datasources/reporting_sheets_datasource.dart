import '../../domain/models/daily_summary_model.dart';

abstract class ReportingSheetsDataSource {
  Future<List<DailySummaryModel>> getDailySummaries();
}

class InMemoryReportingSheetsDataSource implements ReportingSheetsDataSource {
  final List<DailySummaryModel> _summaries = [];

  InMemoryReportingSheetsDataSource({List<DailySummaryModel>? initialSummaries}) {
    if (initialSummaries != null) _summaries.addAll(initialSummaries);
  }

  @override
  Future<List<DailySummaryModel>> getDailySummaries() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_summaries);
  }
}
