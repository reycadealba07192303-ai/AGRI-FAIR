import '../models/address.dart';
import 'api_client.dart';

class AddressService {
  AddressService._();

  static final AddressService instance = AddressService._();

  final _api = ApiClient.instance;

  List<Address> _parse(dynamic body) {
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(Address.fromJson)
        .where((a) => a.id.isNotEmpty)
        .toList();
  }

  Future<List<Address>> list() async => _parse(await _api.get('/user/addresses'));

  /// Every write returns the whole list, so the caller never has to merge one
  /// address into a stale copy and guess which is default now.
  Future<List<Address>> add(Address address) async =>
      _parse(await _api.post('/user/addresses', address.toJson()));

  Future<List<Address>> update(String id, Address address) async =>
      _parse(await _api.put('/user/addresses/$id', address.toJson()));

  Future<List<Address>> remove(String id) async =>
      _parse(await _api.delete('/user/addresses/$id'));

  Future<List<Address>> makeDefault(String id) async =>
      _parse(await _api.put('/user/addresses/$id', {'isDefault': true}));

  /// How to pay one seller. Signed in only - the public profile withholds
  /// account numbers on purpose.
  Future<SellerPayment> paymentFor(int sellerId) async {
    final body = await _api.get('/sellers/$sellerId/payment');
    return SellerPayment.fromJson(body as Map<String, dynamic>);
  }
}
