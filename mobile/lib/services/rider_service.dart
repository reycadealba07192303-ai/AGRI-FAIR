import 'api_client.dart';
import 'delivery_service.dart';

/// One order line a rider has been given: one product, one shop, one door.
class Delivery {
  const Delivery({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.productName,
    required this.quantity,
    required this.total,
    required this.customerName,
    required this.customerContact,
    required this.pickup,
    required this.dropoff,
    this.shopName = '',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.notes = '',
    this.proofOfDelivery = '',
    this.deliveryNote = '',
    this.isLive = false,
    this.deliveredAt,
  });

  final String orderId;
  final String orderNumber;
  final String status;
  final String productName;
  final int quantity;
  final double total;
  final String customerName;
  final String customerContact;
  final String shopName;
  final String paymentMethod;
  final String paymentStatus;
  final String notes;

  final DeliveryPoint pickup;
  final DeliveryPoint dropoff;

  /// The photo taken at the door. Its presence is what "done" means here.
  final String proofOfDelivery;
  final String deliveryNote;
  final bool isLive;
  final DateTime? deliveredAt;

  bool get isDone => proofOfDelivery.isNotEmpty;

  /// Whether the rider still has to collect money at the door.
  bool get collectsCash =>
      paymentStatus != 'paid' && paymentMethod.toLowerCase().contains('cash');

  factory Delivery.fromJson(Map<String, dynamic> json) {
    return Delivery(
      orderId: (json['orderId'] ?? '').toString(),
      orderNumber: (json['orderNumber'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      customerName: (json['customerName'] ?? '').toString(),
      customerContact: (json['customerContact'] ?? '').toString(),
      shopName: (json['shopName'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      paymentStatus: (json['paymentStatus'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      pickup: DeliveryPoint.fromJson(json['pickup'] as Map<String, dynamic>?),
      dropoff: DeliveryPoint.fromJson(json['dropoff'] as Map<String, dynamic>?),
      proofOfDelivery: (json['proofOfDelivery'] ?? '').toString(),
      deliveryNote: (json['deliveryNote'] ?? '').toString(),
      isLive: json['isLive'] == true,
      deliveredAt: DateTime.tryParse((json['deliveredAt'] ?? '').toString()),
    );
  }
}

/// What a delivery rider can do.
///
/// Only orders assigned to them, and only those. Working for the seller is not
/// enough on its own - the assignment is what opens one.
class RiderService {
  RiderService._();

  static final RiderService instance = RiderService._();

  final _api = ApiClient.instance;

  Future<List<Delivery>> myDeliveries() async {
    final body = await _api.get('/riders/me/deliveries');
    if (body is! List) return const [];

    return body
        .whereType<Map<String, dynamic>>()
        .map(Delivery.fromJson)
        .where((d) => d.orderId.isNotEmpty)
        .toList();
  }

  /// Where the truck is, while it is moving.
  Future<void> pushLocation(
    String orderId, {
    required double lat,
    required double lng,
    int? etaMinutes,
  }) async {
    await _api.put('/riders/me/deliveries/$orderId/location', {
      'lat': lat,
      'lng': lng,
      'etaMinutes': ?etaMinutes,
    });
  }

  /// The photo at the door. Marks the line delivered in the same call - the
  /// proof and the status are one event.
  Future<void> uploadProof(
    String orderId, {
    required String photoPath,
    String note = '',
  }) async {
    await _api.postMultipart(
      '/riders/me/deliveries/$orderId/proof',
      fileField: 'proof',
      filePath: photoPath,
      fields: {if (note.trim().isNotEmpty) 'note': note.trim()},
    );
  }
}
