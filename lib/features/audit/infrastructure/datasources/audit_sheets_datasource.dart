import '../../domain/models/quarantine_model.dart';
import '../../domain/models/audit_log_model.dart';
import '../../domain/models/migration_report_model.dart';
import '../../domain/models/checklist_iso_model.dart';

abstract class AuditSheetsDataSource {
  Future<List<QuarantineModel>> getQuarantineRecords();
  Future<List<AuditLogModel>> getAuditLogs();
  Future<List<MigrationReportModel>> getMigrationReports();
  Future<List<ChecklistIsoModel>> getChecklistIsoItems();
}

class InMemoryAuditSheetsDataSource implements AuditSheetsDataSource {
  final List<QuarantineModel> _quarantine = [];
  final List<AuditLogModel> _auditLogs = [];
  final List<MigrationReportModel> _migrationReports = [];
  final List<ChecklistIsoModel> _checklistIso = [];

  InMemoryAuditSheetsDataSource({
    List<QuarantineModel>? initialQuarantine,
    List<AuditLogModel>? initialAuditLogs,
    List<MigrationReportModel>? initialMigrationReports,
    List<ChecklistIsoModel>? initialChecklistIso,
  }) {
    if (initialQuarantine != null) _quarantine.addAll(initialQuarantine);
    if (initialAuditLogs != null) _auditLogs.addAll(initialAuditLogs);
    if (initialMigrationReports != null) _migrationReports.addAll(initialMigrationReports);
    if (initialChecklistIso != null) _checklistIso.addAll(initialChecklistIso);
  }

  @override
  Future<List<QuarantineModel>> getQuarantineRecords() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_quarantine);
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_auditLogs);
  }

  @override
  Future<List<MigrationReportModel>> getMigrationReports() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_migrationReports);
  }

  @override
  Future<List<ChecklistIsoModel>> getChecklistIsoItems() async {
    // No polling. Actualización bajo demanda del usuario.
    return List.unmodifiable(_checklistIso);
  }
}
