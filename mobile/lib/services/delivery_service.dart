import 'api_client.dart';

/// A point on the map, with the words that go under it.
class DeliveryPoint {
  const DeliveryPoint({
    this.lat,
    this.lng,
    this.address = '',
    this.precision = '',
  });

  final double? lat;
  final double? lng;
  final String address;

  /// `exact` when the buyer pinned their own door; `approximate` when the
  /// point is the barangay the address names. Never shown as the same thing -
  /// a rider sent to a barangay centre believing it is a house has been
  /// misled by the map.
  final String precision;

  bool get isApproximate => precision == 'approximate';

  /// Whether this end can actually be drawn.
  ///
  /// An address that was typed but never pinned has words and no point - the
  /// rider can still read it, but the map has nothing to mark.
  bool get hasPoint => lat != null && lng != null;

  factory DeliveryPoint.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DeliveryPoint();

    return DeliveryPoint(
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      address: (json['address'] ?? '').toString(),
      precision: (json['precision'] ?? '').toString(),
    );
  }
}

/// Where one order line is, between the shop it came from and the door it is
/// going to.
class DeliveryTracking {
  const DeliveryTracking({
    required this.orderNumber,
    required this.status,
    required this.productName,
    required this.isLive,
    required this.pickup,
    required this.dropoff,
    this.courierLat,
    this.courierLng,
    this.etaMinutes,
    this.courierName = '',
    this.courierContact = '',
    this.updatedAt,
    this.proofOfDelivery = '',
    this.deliveredAt,
    this.deliveryNote = '',
  });

  final String orderNumber;
  final String status;
  final String productName;

  /// Whether a courier position is being shared right now.
  final bool isLive;

  final DeliveryPoint pickup;
  final DeliveryPoint dropoff;

  final double? courierLat;
  final double? courierLng;
  final int? etaMinutes;
  final String courierName;
  final String courierContact;
  final DateTime? updatedAt;

  /// The photo the rider took at the door, behind the authenticated files
  /// route. The buyer's own gate is in it, so it is readable only by the three
  /// people on the delivery.
  final String proofOfDelivery;
  final DateTime? deliveredAt;
  final String deliveryNote;

  bool get hasProof => proofOfDelivery.isNotEmpty;

  bool get hasCourier =>
      isLive && courierLat != null && courierLng != null;

  /// Whether there is enough to draw anything at all.
  bool get hasMap => pickup.hasPoint || dropoff.hasPoint || hasCourier;

  /// Tracking only means something once the rice has left the shop.
  bool get isOnTheWay => status == 'shipped' || status == 'delivered';

  factory DeliveryTracking.fromJson(Map<String, dynamic> json) {
    return DeliveryTracking(
      orderNumber: (json['orderNumber'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      productName: (json['productName'] ?? '').toString(),
      isLive: json['isLive'] == true,
      pickup: DeliveryPoint.fromJson(json['pickup'] as Map<String, dynamic>?),
      dropoff: DeliveryPoint.fromJson(json['dropoff'] as Map<String, dynamic>?),
      courierLat: (json['lat'] as num?)?.toDouble(),
      courierLng: (json['lng'] as num?)?.toDouble(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      courierName: (json['courierName'] ?? '').toString(),
      courierContact: (json['courierContact'] ?? '').toString(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
      proofOfDelivery: (json['proofOfDelivery'] ?? '').toString(),
      deliveredAt: DateTime.tryParse((json['deliveredAt'] ?? '').toString()),
      deliveryNote: (json['deliveryNote'] ?? '').toString(),
    );
  }
}

class DeliveryService {
  DeliveryService._();

  static final DeliveryService instance = DeliveryService._();

  final _api = ApiClient.instance;

  /// Tracking for one order row - one product, from one seller.
  Future<DeliveryTracking> track(String orderId) async {
    final body = await _api.get('/delivery/$orderId');

    if (body is! Map<String, dynamic>) {
      throw ApiException('The server sent no tracking for this order.');
    }

    return DeliveryTracking.fromJson(body);
  }
}
