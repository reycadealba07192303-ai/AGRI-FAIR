import 'package:flutter/material.dart';

import '../models/address.dart';
import '../models/ph_provinces.dart';
import '../services/address_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';

/// Saved delivery addresses.
///
/// Opened on its own from Profile, or from checkout to pick one - hence
/// [selecting], which turns the rows into choices and pops with the one
/// tapped instead of just showing them.
class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key, this.selecting = false});

  final bool selecting;

  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  List<Address> _addresses = const [];
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final addresses = await AddressService.instance.list();
      if (!mounted) return;
      setState(() {
        _addresses = addresses;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Address? existing}) async {
    final result = await showModalBottomSheet<Address>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _AddressForm(existing: existing),
    );

    if (result == null || !mounted) return;

    setState(() => _busy = true);

    try {
      final list = existing == null
          ? await AddressService.instance.add(result)
          : await AddressService.instance.update(existing.id, result);

      if (!mounted) return;
      setState(() {
        _addresses = list;
        _busy = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(err.message);
    }
  }

  Future<void> _makeDefault(Address address) async {
    if (address.isDefault || _busy) return;
    setState(() => _busy = true);

    try {
      final list = await AddressService.instance.makeDefault(address.id);
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _busy = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(err.message);
    }
  }

  Future<void> _remove(Address address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Remove this address?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${address.label} — ${address.formatted}',
          style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);

    try {
      final list = await AddressService.instance.remove(address.id);
      if (!mounted) return;
      setState(() {
        _addresses = list;
        _busy = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      _notify(err.message);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          child: ClayIconButton(
            icon: Icons.arrow_back_rounded,
            size: 38,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
        leadingWidth: 62,
        title: Text(widget.selecting ? 'Choose address' : 'My Addresses'),
      ),
      body: _body(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: ClayButton(
            label: 'Add a new address',
            icon: Icons.add_rounded,
            onPressed: _busy ? null : () => _openForm(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        children: const [
          ClaySkeleton(height: 116, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 116, radius: AppRadius.lg),
        ],
      );
    }

    if (_error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Cannot load your addresses',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_addresses.isEmpty) {
      return const ClayEmptyState(
        icon: Icons.location_off_outlined,
        title: 'No saved addresses',
        message: 'Add one and it will be used for your orders.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryMedium,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        itemCount: _addresses.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _AddressCard(
          address: _addresses[i],
          selecting: widget.selecting,
          onTap: widget.selecting
              ? () => Navigator.of(context).pop(_addresses[i])
              : () => _makeDefault(_addresses[i]),
          onEdit: () => _openForm(existing: _addresses[i]),
          onRemove: () => _remove(_addresses[i]),
          onMakeDefault: () => _makeDefault(_addresses[i]),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    required this.address,
    required this.selecting,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
    required this.onMakeDefault,
  });

  final Address address;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onMakeDefault;

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                address.label.toLowerCase() == 'work'
                    ? Icons.business_rounded
                    : Icons.home_rounded,
                size: 16,
                color: AppColors.primaryMedium,
              ),
              const SizedBox(width: 7),
              Text(
                address.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 8),
              if (address.isDefault)
                const ClayBadge(label: 'Default', compact: true),
              const Spacer(),
              if (selecting && address.isDefault)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 19,
                  color: AppColors.primaryMedium,
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            address.fullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            address.contact,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 5),
          Text(
            address.formatted,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textBody,
              height: 1.4,
            ),
          ),
          if (address.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address.notes,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (!selecting) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            Row(
              children: [
                if (!address.isDefault)
                  TextButton(
                    onPressed: onMakeDefault,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryMedium,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Set as default',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Remove',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({this.existing});

  final Address? existing;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _formKey = GlobalKey<FormState>();

  late final _label = TextEditingController(text: widget.existing?.label ?? 'Home');
  late final _fullName = TextEditingController(text: widget.existing?.fullName);
  late final _contact = TextEditingController(text: widget.existing?.contact);
  late final _line = TextEditingController(text: widget.existing?.line);
  late final _barangay = TextEditingController(text: widget.existing?.barangay);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _notes = TextEditingController(text: widget.existing?.notes);

  late String _province = widget.existing?.province ?? '';
  late bool _isDefault = widget.existing?.isDefault ?? false;

  @override
  void dispose() {
    for (final c in [
      _label,
      _fullName,
      _contact,
      _line,
      _barangay,
      _city,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Address(
        id: widget.existing?.id ?? '',
        label: _label.text.trim().isEmpty ? 'Home' : _label.text.trim(),
        fullName: _fullName.text.trim(),
        contact: _contact.text.trim(),
        line: _line.text.trim(),
        barangay: _barangay.text.trim(),
        city: _city.text.trim(),
        province: _province,
        notes: _notes.text.trim(),
        isDefault: _isDefault,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the sheet clear of the keyboard, or the last fields sit under it.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, controller) => Form(
          key: _formKey,
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSunken,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.existing == null ? 'New address' : 'Edit address',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              _field(_label, 'Label', hint: 'Home, Work, Bahay ni Nanay'),
              const SizedBox(height: 12),
              _field(
                _fullName,
                'Full name',
                required: true,
                message: 'Who will receive this?',
              ),
              const SizedBox(height: 12),
              _field(
                _contact,
                'Contact number',
                required: true,
                message: 'The rider needs a number to call.',
                hint: '09XX XXX XXXX',
                keyboard: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _ProvinceField(
                value: _province,
                onChanged: (value) => setState(() => _province = value),
              ),
              const SizedBox(height: 12),
              _field(
                _city,
                'City or municipality',
                required: true,
                message: 'Which city or town?',
              ),
              const SizedBox(height: 12),
              _field(_barangay, 'Barangay', hint: 'Optional'),
              const SizedBox(height: 12),
              _field(
                _line,
                'House number and street',
                required: true,
                message: 'Which street or purok?',
                hint: 'Blk 48 Lot 71, Rizal St.',
              ),
              const SizedBox(height: 12),
              _field(
                _notes,
                'Landmark',
                hint: 'Optional — green gate beside the sari-sari store',
                lines: 2,
              ),
              const SizedBox(height: 16),
              ClaySunken(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Use as my default address',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Switch(
                      value: _isDefault,
                      activeThumbColor: AppColors.primaryMedium,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ClayButton(label: 'Save address', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? message,
    String? hint,
    TextInputType? keyboard,
    int lines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: lines,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (v) => (v?.trim().isEmpty ?? true) ? message : null
          : null,
    );
  }
}

/// Province as a choice rather than typed text.
///
/// A typed province comes back as "Nueva Ecjia" or "N. Ecija" often enough to
/// matter when a rider reads it. Eighty-three entries is too many to scroll,
/// so the sheet opens with a search box.
class _ProvinceField extends StatelessWidget {
  const _ProvinceField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => const _ProvinceSheet(),
    );

    if (chosen != null) onChanged(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;

    return GestureDetector(
      onTap: () => _pick(context),
      behavior: HitTestBehavior.opaque,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Province',
          suffixIcon: Icon(
            Icons.expand_more_rounded,
            color: AppColors.textMuted,
            size: 22,
          ),
        ),
        // Keeps the label floating even when nothing is picked, so the field
        // does not sit there looking like an empty box with a hint.
        isEmpty: false,
        child: Text(
          empty ? 'Choose a province' : value,
          style: TextStyle(
            fontSize: 15,
            color: empty ? AppColors.textMuted : AppColors.textDark,
            fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ProvinceSheet extends StatefulWidget {
  const _ProvinceSheet();

  @override
  State<_ProvinceSheet> createState() => _ProvinceSheetState();
}

class _ProvinceSheetState extends State<_ProvinceSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = PhProvinces.search(_search.text);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.92,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Province',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Search',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 21,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'No province matched that.',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: matches.length,
                      itemBuilder: (context, i) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          matches[i],
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                        onTap: () => Navigator.of(context).pop(matches[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
