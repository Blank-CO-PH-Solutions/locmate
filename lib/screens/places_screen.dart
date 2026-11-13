import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/member.dart';
import '../models/place.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/member_avatar.dart';

class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            ScreenHeader(
              title: 'Places',
              subtitle: 'Arrival and departure alerts for your circle',
              actions: [
                IconButton.filled(
                  onPressed: () => _showAddPlace(context),
                  tooltip: 'Add a place',
                  icon: const Icon(Icons.add_location_alt_rounded, size: 22),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Everyone in ${AppState.circleName} gets an alert '
                            'when a member comes or goes.',
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.places.isEmpty)
                    const SurfaceCard(
                      child: EmptyState(
                        icon: Icons.place_rounded,
                        title: 'No places yet',
                        message: 'Add Home, School or Work to get alerts.',
                      ),
                    )
                  else
                    for (final place in state.places)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlaceCard(
                          place: place,
                          members: state.membersAtPlace(place),
                          onRemove: () => _confirmRemove(context, place),
                        ),
                      ),
                  const SizedBox(height: 4),
                  _AddPlaceTile(onTap: () => _showAddPlace(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddPlace(BuildContext context) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddPlaceSheet(),
    );
    if (added == true && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Place added to your circle')),
        );
    }
  }

  Future<void> _confirmRemove(BuildContext context, Place place) async {
    final state = context.read<AppState>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove place?'),
        content: Text(
          '${place.name} will no longer trigger arrival or departure alerts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: LocmateColors.danger,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    state.removePlace(place.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${place.name} removed')));
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({
    required this.place,
    required this.members,
    required this.onRemove,
  });

  final Place place;
  final List<Member> members;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = placeColor(place.icon);
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(placeIcon(place.icon), color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  place.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 7),
                if (members.isEmpty)
                  Row(
                    children: [
                      Icon(
                        Icons.person_off_outlined,
                        size: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'No one here right now',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      _AvatarStack(members: members, size: 22),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${members.map((member) => member.firstName).join(', ')} here',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: scheme.onSurfaceVariant,
            ),
            onSelected: (_) => onRemove(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('Remove place'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.members, this.size = 24});

  final List<Member> members;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(4).toList();
    return SizedBox(
      width: size + (shown.length - 1) * (size * 0.62),
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.62,
              child: MemberAvatar(member: shown[i], size: size),
            ),
        ],
      ),
    );
  }
}

class _AddPlaceTile extends StatelessWidget {
  const _AddPlaceTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.add_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add another place',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaPreset {
  const _AreaPreset(this.label, this.address, this.point);

  final String label;
  final String address;
  final LatLng point;
}

class _AddPlaceSheet extends StatefulWidget {
  const _AddPlaceSheet();

  @override
  State<_AddPlaceSheet> createState() => _AddPlaceSheetState();
}

class _AddPlaceSheetState extends State<_AddPlaceSheet> {
  static const _presets = [
    _AreaPreset(
      'Riverside Park',
      '410 River Rd',
      LatLng(30.2650, -97.7500),
    ),
    _AreaPreset(
      'Northside Mall',
      '900 Northside Blvd',
      LatLng(30.2780, -97.7300),
    ),
    _AreaPreset(
      'Downtown',
      '100 Congress Ave',
      LatLng(30.2672, -97.7431),
    ),
    _AreaPreset(
      'Eastwood Library',
      '55 Eastwood Ln',
      LatLng(30.2690, -97.7320),
    ),
  ];

  static const _categories = [
    ('home', 'Home', Icons.home_rounded),
    ('work', 'Work', Icons.work_rounded),
    ('school', 'School', Icons.school_rounded),
    ('gym', 'Gym', Icons.fitness_center_rounded),
    ('other', 'Other', Icons.place_rounded),
  ];

  final TextEditingController _nameController = TextEditingController();
  String _category = 'home';
  int _presetIndex = 0;
  double _radius = 180;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give this place a name first.');
      return;
    }
    final preset = _presets[_presetIndex];
    context.read<AppState>().addPlace(
          name: name,
          category: _category,
          address: preset.address,
          point: preset.point,
          radiusMeters: _radius,
        );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add a place',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: const InputDecoration(
                hintText: "Place name (e.g. Grandma's house)",
                prefixIcon: Icon(Icons.edit_location_alt_outlined),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: LocmateColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              'Category',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in _categories)
                  ChoiceChip(
                    label: Text(category.$2),
                    avatar: Icon(
                      category.$3,
                      size: 16,
                      color: _category == category.$1
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    selected: _category == category.$1,
                    onSelected: (_) =>
                        setState(() => _category = category.$1),
                    showCheckmark: false,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Area',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            DropdownMenu<int>(
              initialSelection: _presetIndex,
              expandedInsets: EdgeInsets.zero,
              menuHeight: 280,
              leadingIcon: Icon(
                Icons.map_outlined,
                size: 20,
                color: scheme.onSurfaceVariant,
              ),
              label: const Text('Choose an area'),
              dropdownMenuEntries: [
                for (var i = 0; i < _presets.length; i++)
                  DropdownMenuEntry(
                    value: i,
                    label:
                        '${_presets[i].label} · ${_presets[i].address}',
                  ),
              ],
              onSelected: (value) {
                if (value != null) setState(() => _presetIndex = value);
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  'Alert radius',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_radius.round()} m',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            Slider(
              value: _radius,
              min: 100,
              max: 500,
              divisions: 8,
              label: '${_radius.round()} m',
              onChanged: (value) => setState(() => _radius = value),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.add_location_alt_rounded, size: 19),
              label: const Text('Save place'),
            ),
          ],
        ),
      ),
    );
  }
}
