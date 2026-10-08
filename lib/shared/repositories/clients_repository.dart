import '../models/client.dart';
import 'repository_base.dart';

class ClientsRepository extends RepositoryBase {
  ClientsRepository({required super.client, required super.cache, required super.onOffline});

  static const pageSize = 30;

  Future<List<ClientSummary>> list({String query = '', int offset = 0, int limit = pageSize}) async {
    final q = RepositoryBase.sanitizeSearch(query);
    final cacheKey = (q.isEmpty && offset == 0) ? 'clients:first' : null;
    final data = await read(cacheKey, () {
      var builder = client.from('client_summary').select();
      if (q.isNotEmpty) {
        final digits = q.replaceAll(RegExp(r'\D'), '');
        builder = digits.length >= 3
            ? builder.or('name.ilike.*$q*,phone.ilike.*$digits*,cpf.ilike.*$digits*')
            : builder.ilike('name', '*$q*');
      }
      return builder.order('name', ascending: true).range(offset, offset + limit - 1);
    });
    return RepositoryBase.rows(data).map(ClientSummary.fromJson).toList();
  }

  /// Clientes recentes para o seletor rápido da nova operação.
  Future<List<Client>> recent({int limit = 8}) async {
    final data = await read('clients:recent', () {
      return client.from('clients').select().order('updated_at', ascending: false).limit(limit);
    });
    return RepositoryBase.rows(data).map(Client.fromJson).toList();
  }

  Future<ClientSummary> get(String id) async {
    final data = await read('client:$id', () => client.from('client_summary').select().eq('id', id).single());
    return ClientSummary.fromJson(RepositoryBase.row(data));
  }

  Future<Client> create(ClientInput input) {
    return write(() async {
      final data = await client.from('clients').insert(input.toJson()).select().single();
      return Client.fromJson(data);
    });
  }

  Future<Client> update(String id, ClientInput input) {
    return write(() async {
      final data = await client.from('clients').update(input.toJson()).eq('id', id).select().single();
      return Client.fromJson(data);
    });
  }
}
