import '../../domain/entities/order.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.orderCode,
    required super.status,
    super.paymentStatus,
    super.paymentMethodCode,
    super.paymentMethodName,
    required super.fulfillmentType,
    super.branchId,
    required super.branchName,
    super.branchPhone,
    super.branchAddress,
    super.branchReference,
    super.branchLat,
    super.branchLng,
    required super.deliveryAddress,
    super.deliveryReference,
    super.deliveryDistrict,
    super.deliveryLat,
    super.deliveryLng,
    super.recipientName,
    super.recipientPhone,
    super.estimatedDistanceKm,
    super.estimatedTimeMin,
    required super.subtotal,
    required super.deliveryFee,
    required super.tipAmount,
    required super.total,
    super.cashChangeFor,
    required super.currency,
    super.specialInstructions,
    super.placedAt,
    super.acceptedAt,
    super.pickedUpAt,
    super.deliveredAt,
    super.cancelledAt,
    required super.createdAt,
  });

  /// Espera un row de `orders` con embeds:
  /// `*, order_delivery_details(*),
  ///  merchant_branches(name,phone,lat,lng,addresses(line1,district,city,reference))`
  factory OrderModel.fromJson(Map<String, dynamic> j) {
    double? toD(dynamic v) => v == null ? null : (v as num).toDouble();
    double toDz(dynamic v) => v == null ? 0.0 : (v as num).toDouble();
    DateTime? toDt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    // Embeds (pueden venir como objeto o lista de un elemento).
    Map<String, dynamic>? one(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is List && v.isNotEmpty && v.first is Map) {
        return v.first as Map<String, dynamic>;
      }
      return null;
    }

    final branch = one(j['merchant_branches']) ?? const {};
    final branchAddr = one(branch['addresses']) ?? const {};
    final dd = one(j['order_delivery_details']) ?? const {};
    final pm = one(j['payment_method']) ?? const {};

    // Construye la dirección de texto del local a partir de la tabla addresses.
    String? composeBranchAddress() {
      final parts = [
        branchAddr['line1'],
        branchAddr['district'],
      ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();
      return parts.isEmpty ? null : parts.join(', ');
    }

    return OrderModel(
      id: j['id'] as String,
      orderCode: (j['order_code'] as num?)?.toInt() ?? 0,
      status: OrderStatusX.fromString(j['status'] as String?),
      paymentStatus: j['payment_status'] as String?,
      paymentMethodCode: pm['code'] as String? ?? '',
      paymentMethodName: pm['name'] as String? ?? '',
      fulfillmentType: j['fulfillment_type'] as String? ?? 'delivery',
      branchId: j['branch_id'] as String?,
      branchName: branch['name'] as String? ?? 'Local',
      branchPhone: branch['phone'] as String?,
      branchAddress: composeBranchAddress(),
      branchReference: branchAddr['reference'] as String?,
      branchLat: toD(branch['lat']),
      branchLng: toD(branch['lng']),
      deliveryAddress: dd['address_snapshot'] as String? ?? 'Dirección no disponible',
      deliveryReference: dd['reference_snapshot'] as String?,
      deliveryDistrict: dd['district_snapshot'] as String?,
      deliveryLat: toD(dd['lat']),
      deliveryLng: toD(dd['lng']),
      recipientName: dd['recipient_name'] as String?,
      recipientPhone: dd['recipient_phone'] as String?,
      estimatedDistanceKm: toD(dd['estimated_distance_km']),
      estimatedTimeMin: (dd['estimated_time_min'] as num?)?.toInt(),
      subtotal: toDz(j['subtotal']),
      deliveryFee: toDz(j['delivery_fee']),
      tipAmount: toDz(j['tip_amount']),
      total: toDz(j['total']),
      cashChangeFor: toD(j['cash_change_for']),
      currency: j['currency'] as String? ?? 'PEN',
      specialInstructions: j['special_instructions'] as String?,
      placedAt: toDt(j['placed_at']),
      acceptedAt: toDt(j['accepted_at']),
      pickedUpAt: toDt(j['picked_up_at']),
      deliveredAt: toDt(j['delivered_at']),
      cancelledAt: toDt(j['cancelled_at']),
      createdAt: toDt(j['created_at']) ?? DateTime.now(),
    );
  }
}
