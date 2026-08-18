import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/rate_cities_api_client.dart';
import '../models/pakistan_cities.dart';

/// A tap-to-choose city field.
///
/// Shared by the workshop setup form and Rates settings so the two can never
/// drift into offering different cities -- the city is what selects a rate
/// list, and a city that exists on one screen but not the other would mean a
/// workshop pointing at rates that are not there.
///
/// Deliberately not a free text box: "lahor" would quietly miss its rate list.
class CityPickerField extends StatelessWidget {
  /// The chosen city, or empty when nothing has been picked yet.
  final String value;
  final ValueChanged<String> onChanged;

  /// Shown under the field. The two callers want to say different things
  /// about the same choice.
  final String? helperText;

  /// Which cities actually have a rate list, once the server has said.
  ///
  /// Null while it is still being fetched, and [RateCitiesAvailability.known]
  /// is false if the fetch failed — in both cases the field says nothing about
  /// availability rather than guessing.
  final RateCitiesAvailability? availability;

  final bool enabled;

  const CityPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.helperText,
    this.availability,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext ctx) => _CityListSheet(selected: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final bool chosen = value.trim().isNotEmpty;
    // Only once we actually know, and only about a city that has been picked.
    // If the lookup failed we say nothing rather than guess.
    final bool missingList =
        chosen &&
        availability != null &&
        availability!.known &&
        !availability!.hasListFor(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          key: const Key('city_picker_field'),
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? () => _pick(context) : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'City',
              helperText: helperText,
              helperMaxLines: 3,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.location_city_rounded),
              suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              enabled: enabled,
            ),
            child: Text(
              chosen ? value : 'Choose your city',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: chosen ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: chosen ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
        if (missingList) ...<Widget>[
          const SizedBox(height: 10),
          _MissingRateListNotice(
            city: value,
            supportPhone: availability!.supportPhone,
            hasFallback: availability!.hasFallback,
          ),
        ],
      ],
    );
  }
}

/// Says plainly that this city has no rate list yet, and who to ring.
///
/// It does not block the choice. Someone setting up their workshop for the
/// first time must be able to finish; what they must not do is walk away
/// believing their rates are their city's when they are not.
class _MissingRateListNotice extends StatelessWidget {
  final String city;
  final String supportPhone;
  final bool hasFallback;

  const _MissingRateListNotice({
    required this.city,
    required this.supportPhone,
    required this.hasFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('city_missing_rate_list_notice'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '$city ki rate list abhi upload nahi hui',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasFallback
                      ? 'Filhaal aap ko aam rate list mil rahi hai. Apne '
                            'sheher ki list ke liye is number par rabta '
                            'karein — aur tab tak rates khud bhi badal sakte '
                            'hain.'
                      : 'Abhi koi rate list mojood nahi. Is number par rabta '
                            'karein.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  supportPhone,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The list itself, with a search box because twenty-odd cities is more than
/// anyone wants to scroll past on a phone.
class _CityListSheet extends StatefulWidget {
  final String selected;

  const _CityListSheet({required this.selected});

  @override
  State<_CityListSheet> createState() => _CityListSheetState();
}

class _CityListSheetState extends State<_CityListSheet> {
  String _query = '';

  List<String> get _visible {
    final String q = _query.trim().toLowerCase();
    if (q.isEmpty) return PakistanCities.all;
    return PakistanCities.all
        .where((String c) => c.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<String> cities = _visible;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Choose your city',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rates differ from city to city, so this decides which '
                      'rate list you start from.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('city_search_field'),
                      autofocus: false,
                      onChanged: (String v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: cities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No city by that name. Pick the city you buy your '
                            'material from — those are the rates that apply to '
                            'you.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: cities.length,
                        itemBuilder: (BuildContext context, int index) {
                          final String city = cities[index];
                          final bool selected = city == widget.selected;
                          return ListTile(
                            key: Key('city_option_${PakistanCities.slug(city)}'),
                            title: Text(
                              city,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w900
                                        : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.royalBlue,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(city),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
