import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_client.dart';
import '../services/delivery_service.dart';
import '../theme/app_theme.dart';
import 'clay.dart';
import 'private_image.dart';

/// Where one product is between the shop and the door.
///
/// Three points, and the map shows whichever of them exist: the shop it is
/// collected from, the address it is going to, and the rider when one is
/// sharing a position. Deliberately not gated on the rider - the two ends are
/// known the moment the order exists, and seeing them is most of what makes a
/// delivery feel accountable.
///
/// OpenStreetMap tiles, the same ones the seller's web dashboard draws, so
/// both sides of a delivery are looking at the same map and neither needs an
/// API key.
class DeliveryMapCard extends StatefulWidget {
  const DeliveryMapCard({
    super.key,
    required this.orderId,
    required this.productName,
  });

  final String orderId;
  final String productName;

  @override
  State<DeliveryMapCard> createState() => _DeliveryMapCardState();
}

class _DeliveryMapCardState extends State<DeliveryMapCard> {
  final _map = MapController();

  DeliveryTracking? _tracking;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final tracking = await DeliveryService.instance.track(widget.orderId);
      if (!mounted) return;
      setState(() {
        _tracking = tracking;
        _loading = false;
        _error = null;
      });
      _fitToRoute();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  List<LatLng> get _points {
    final t = _tracking;
    if (t == null) return const [];

    return [
      if (t.pickup.hasPoint) LatLng(t.pickup.lat!, t.pickup.lng!),
      if (t.hasCourier) LatLng(t.courierLat!, t.courierLng!),
      if (t.dropoff.hasPoint) LatLng(t.dropoff.lat!, t.dropoff.lng!),
    ];
  }

  /// Frames every point that exists, rather than centring on one of them - a
  /// map zoomed to the shop with the destination off-screen answers nothing.
  void _fitToRoute() {
    final points = _points;
    if (points.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (points.length == 1) {
        _map.move(points.first, 15);
        return;
      }

      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(42),
          maxZoom: 16,
        ),
      );
    });
  }

  /// Straight-line distance, which is honest about being straight: this is not
  /// a routed distance and the card says so rather than implying road mileage.
  double? get _straightLineKm {
    final t = _tracking;
    if (t == null || !t.pickup.hasPoint || !t.dropoff.hasPoint) return null;

    const earthKm = 6371.0;
    final dLat = _rad(t.dropoff.lat! - t.pickup.lat!);
    final dLng = _rad(t.dropoff.lng! - t.pickup.lng!);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(t.pickup.lat!)) *
            math.cos(_rad(t.dropoff.lat!)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double degrees) => degrees * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ClaySkeleton(height: 250, radius: AppRadius.lg);
    }

    final t = _tracking;
    if (_error != null || t == null) {
      return ClayCard(
        child: Row(
          children: [
            const Icon(Icons.map_outlined, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error ?? 'No tracking for this item.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
            ),
            GestureDetector(
              onTap: _load,
              behavior: HitTestBehavior.opaque,
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryMedium,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ClayCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(t),
          const SizedBox(height: 12),
          if (t.hasProof)
            _proof(t)
          else if (t.hasMap)
            _map3(t)
          else
            _noPoints(t),
          const SizedBox(height: 12),
          _legs(t),
        ],
      ),
    );
  }

  Widget _heading(DeliveryTracking t) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                t.hasProof
                    ? 'Delivered${t.courierName.isEmpty ? '' : ' by ${t.courierName}'}'
                    : t.hasCourier
                        ? '${t.courierName.isEmpty ? 'The rider' : t.courierName} is sharing their location'
                        : t.courierName.isNotEmpty
                            ? '${t.courierName} is carrying this'
                            : t.isOnTheWay
                                ? 'On the way — no rider assigned yet'
                                : 'Pickup and delivery points',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (t.etaMinutes != null)
          ClayBadge(label: '~${t.etaMinutes} min', compact: true),
      ],
    );
  }

  Widget _map3(DeliveryTracking t) {
    final points = _points;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: 210,
        child: FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: points.first,
            initialZoom: 14,
            interactionOptions: const InteractionOptions(
              // No rotation: a delivery map that has been spun is harder to
              // read, not easier, and there is no compass here to undo it.
              flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ph.agrifair.mobile',
            ),
            if (points.length > 1)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: 3,
                    color: AppColors.primaryMedium.withValues(alpha: 0.65),
                    // Dashed, because this is the line between two places and
                    // not the road a rider will actually take.
                    pattern: StrokePattern.dashed(segments: const [7, 6]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (t.pickup.hasPoint)
                  _pin(
                    LatLng(t.pickup.lat!, t.pickup.lng!),
                    Icons.storefront_rounded,
                    AppColors.primaryDark,
                  ),
                if (t.dropoff.hasPoint)
                  _pin(
                    LatLng(t.dropoff.lat!, t.dropoff.lng!),
                    // A different mark for a different promise: a barangay
                    // pin is an area, and drawing it as a house would say
                    // something the data cannot support.
                    t.dropoff.isApproximate
                        ? Icons.my_location_rounded
                        : Icons.home_rounded,
                    AppColors.accent,
                  ),
                if (t.hasCourier)
                  _pin(
                    LatLng(t.courierLat!, t.courierLng!),
                    Icons.local_shipping_rounded,
                    AppColors.error,
                  ),
              ],
            ),
            // Required by the tile licence, not decoration.
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// The photo taken at the door.
  ///
  /// Once it exists the journey is over, so it takes the map's place: where
  /// the truck was is no longer the question, and what arrived is.
  Widget _proof(DeliveryTracking t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => showPrivateImage(
            context,
            path: t.proofOfDelivery,
            title: 'Proof of delivery',
          ),
          child: PrivateImage(
            path: t.proofOfDelivery,
            height: 190,
            width: double.infinity,
            radius: AppRadius.md,
            fallbackIcon: Icons.local_shipping_rounded,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (t.deliveryNote.isNotEmpty) t.deliveryNote,
            'Tap to see it full size.',
          ].join(' '),
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Marker _pin(LatLng at, IconData icon, Color color) {
    return Marker(
      point: at,
      width: 34,
      height: 34,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0x3D000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  /// Nothing to draw. Says which end is missing, because that is the thing
  /// somebody can go and fix.
  Widget _noPoints(DeliveryTracking t) {
    return ClaySunken(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_off_outlined,
                  size: 17, color: AppColors.textMuted),
              SizedBox(width: 8),
              Text(
                'No map for this item yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (!t.pickup.hasPoint) 'The seller has not pinned their shop',
              if (!t.dropoff.hasPoint)
                'This address could not be placed on the map',
            ].join('. '),
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// The two ends in words, under the map. The pin says where; this says what.
  Widget _legs(DeliveryTracking t) {
    final km = _straightLineKm;

    return Column(
      children: [
        _leg(
          Icons.storefront_rounded,
          AppColors.primaryDark,
          'Picked up from',
          t.pickup.address.isEmpty
              ? (t.pickup.hasPoint ? 'The seller\'s pinned shop' : 'Not set by the seller')
              : t.pickup.address,
        ),
        const SizedBox(height: 8),
        _leg(
          Icons.home_rounded,
          AppColors.accent,
          t.dropoff.isApproximate ? 'Delivering to (approximate pin)' : 'Delivering to',
          t.dropoff.address.isEmpty ? 'No address on this order' : t.dropoff.address,
        ),
        if (t.dropoff.isApproximate) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const SizedBox(width: 30),
              Expanded(
                child: Text(
                  // Said plainly: the pin is the barangay, and the rider still
                  // needs the landmark to find the door.
                  'The pin is the barangay, not the door. The rider follows the '
                  'written address from there.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (km != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 30),
              Text(
                '${km.toStringAsFixed(1)} km apart in a straight line',
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _leg(IconData icon, Color color, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 22,
          width: 22,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textBody,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
