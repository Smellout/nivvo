import '../../core/utils/dates.dart';
import '../models/summaries.dart';
import 'repository_base.dart';

class ReportsRepository extends RepositoryBase {
  ReportsRepository({required super.client, required super.cache, required super.onOffline});

  Future<ReportSummary> summary(DateTime from, DateTime to) async {
    final key = 'report:${Dates.toJson(from)}:${Dates.toJson(to)}';
    final data = await read(key, () {
      return client.rpc('report_summary', params: {'p_from': Dates.toJson(from), 'p_to': Dates.toJson(to)});
    });
    return ReportSummary.fromJson(RepositoryBase.row(data));
  }
}
