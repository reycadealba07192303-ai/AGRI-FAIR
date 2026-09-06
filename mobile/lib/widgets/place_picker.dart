import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'clay.dart';

/// A field that opens a searchable list instead of taking typed text.
///
/// Used for province, city and barangay. Those lists run to eighty, a hundred
/// and sometimes three hundred entries, so every one opens on a search box
/// rather than a scroll.
class PlacePickerField extends StatelessWidget {
  const PlacePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    required this.load,
    this.enabled = true,
    this.disabledHint,
    this.emptyHint,
  });

  final String label;
  final String value;
  final ValueChanged<PickedPlace> onPicked;

  /// Fetched when the sheet opens, not when the field is drawn - the list for
  /// a city nobody has chosen yet is not worth a request.
  final Future<List<PickedPlace>> Function() load;

  /// A city field with no province chosen has nothing to offer.
  final bool enabled;
  final String? disabledHint;
  final String? emptyHint;

  Future<void> _open(BuildContext context) async {
    if (!enabled) return;

    final picked = await showModalBottomSheet<PickedPlace>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) => _PlaceSheet(title: label, load: load),
    );

    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty;

    final text = empty
        ? (enabled
            ? (emptyHint ?? 'Choose $label')
            : (disabledHint ?? 'Choose the one above first'))
        : value;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: () => _open(context),
        behavior: HitTestBehavior.opaque,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(
              Icons.expand_more_rounded,
              color: AppColors.textMuted,
              size: 22,
            ),
          ),
          // Keeps the label floating with nothing picked, so the field does
          // not read as an empty box with a stray hint in it.
          isEmpty: false,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              color: empty ? AppColors.textMuted : AppColors.textDark,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry in a picker. A barangay has no code, so it carries an empty one.
class PickedPlace {
  const PickedPlace({required this.name, this.code = '', this.oldName = ''});

  final String name;
  final String code;
  final String oldName;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;

    return name.toLowerCase().contains(q) || oldName.toLowerCase().contains(q);
  }
}

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.title, required this.load});

  final String title;
  final Future<List<PickedPlace>> Function() load;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  final _search = TextEditingController();

  List<PickedPlace> _all = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final places = await widget.load();
      if (!mounted) return;
      setState(() {
        _all = places;
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

  @override
  Widget build(BuildContext context) {
    final matches = _all.where((p) => p.matches(_search.text)).toList();

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
                  Row(
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!_loading && _error == null)
                        Text(
                          '${_all.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
            Expanded(child: _list(matches, controller)),
          ],
        ),
      ),
    );
  }

  Widget _list(List<PickedPlace> matches, ScrollController controller) {
    if (_loading) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: const [
          ClaySkeleton(height: 20),
          SizedBox(height: 14),
          ClaySkeleton(height: 20),
          SizedBox(height: 14),
          ClaySkeleton(height: 20),
        ],
      );
    }

    if (_error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Cannot load the list',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _all.isEmpty
                ? 'Nothing is listed here yet.'
                : 'Nothing matched "${_search.text.trim()}".',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: matches.length,
      itemBuilder: (context, i) {
        final place = matches[i];

        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(
            place.name,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
          // Shown when a place was renamed, so the old name being searchable
          // does not look like a mismatch.
          subtitle: place.oldName.isEmpty
              ? null
              : Text(
                  'formerly ${place.oldName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
          onTap: () => Navigator.of(context).pop(place),
        );
      },
    );
  }
}
