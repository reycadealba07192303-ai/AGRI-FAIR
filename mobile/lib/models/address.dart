/// A saved delivery address.
///
/// Exactly one in the list is the default, and the server keeps it that way -
/// deleting the default promotes another - so checkout can always preselect
/// one rather than opening on nothing.
class Address {
  const Address({
    required this.id,
    required this.label,
    required this.fullName,
    required this.contact,
    required this.line,
    required this.city,
    required this.isDefault,
    this.barangay = '',
    this.province = '',
    this.notes = '',
  });

  final String id;

  /// "Home", "Work" - what the buyer calls it, not part of the address.
  final String label;
  final String fullName;
  final String contact;
  final String line;
  final String barangay;
  final String city;
  final String province;

  /// "Green gate beside the sari-sari store" - what actually gets a rider to
  /// the door.
  final String notes;
  final bool isDefault;

  /// The address as one line, for the order and for the courier.
  String get formatted => [
        line,
        if (barangay.isNotEmpty) barangay,
        city,
        if (province.isNotEmpty) province,
      ].join(', ');

  /// What the card shows under the name - everything but the street, which is
  /// already on the line above it.
  String get areaLine => [
        if (barangay.isNotEmpty) barangay,
        city,
        if (province.isNotEmpty) province,
      ].join(', ');

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      label: (json['label'] ?? 'Home').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      contact: (json['contact'] ?? '').toString(),
      line: (json['line'] ?? '').toString(),
      barangay: (json['barangay'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      province: (json['province'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'fullName': fullName,
        'contact': contact,
        'line': line,
        'barangay': barangay,
        'city': city,
        'province': province,
        'notes': notes,
        'isDefault': isDefault,
      };
}

/// How to pay one seller.
///
/// [available] is false when the seller has no payout a Super Admin has
/// verified. The app offers cash on delivery in that case rather than showing
/// an empty QR box - and the server sends no account details at all, since an
/// unchecked QR could send money anywhere.
class SellerPayment {
  const SellerPayment({
    required this.sellerId,
    required this.sellerName,
    required this.available,
    this.method = 'gcash',
    this.accountName = '',
    this.accountNumber = '',
    this.qrImage = '',
    this.reason = '',
  });

  final int sellerId;
  final String sellerName;
  final bool available;
  final String method;
  final String accountName;
  final String accountNumber;

  /// A path under the authenticated /api/files route, never a public URL.
  final String qrImage;
  final String reason;

  bool get hasQr => qrImage.isNotEmpty;

  factory SellerPayment.fromJson(Map<String, dynamic> json) {
    return SellerPayment(
      sellerId: (json['sellerId'] as num?)?.toInt() ?? 0,
      sellerName: (json['sellerName'] ?? '').toString(),
      available: json['available'] == true,
      method: (json['method'] ?? 'gcash').toString(),
      accountName: (json['accountName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      qrImage: (json['qrImage'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
    );
  }
}

enum PaymentMethod {
  cashOnDelivery('Cash/COD', 'Cash on Delivery'),
  gcash('GCash', 'GCash');

  const PaymentMethod(this.wireValue, this.label);

  /// What the backend stores on the order.
  final String wireValue;
  final String label;
}
