// lib/screens/children_screen.dart
import 'package:flutter/material.dart';
import '../models/child.dart';
import '../data/children_store.dart';
import '../data/search_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/child_avatar.dart';
import '../widgets/empty_illustration.dart';
import 'child_profile_screen.dart';

enum _StatusFilter { enrolled, withdrawn, all }

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key, this.onRegister});

  final VoidCallback? onRegister;

  @override
  State<ChildrenScreen> createState() => _ChildrenScreenState();
}

class _ChildrenScreenState extends State<ChildrenScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.enrolled;

  @override
  void initState() {
    super.initState();
    ChildrenStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    ChildrenStore.instance.removeListener(_onStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  bool _matchesQuery(Child child, String q) {
    final normalizedQuery = normalizeForSearch(q);
    if (normalizedQuery.isEmpty) return true;

    final haystacks = <String>[
      normalizeForSearch(child.fullName),
      ...child.guardians.map((g) => normalizeForSearch(g.name)),
      ...child.guardians.map((g) => normalizeForSearch(g.phone)),
    ];
    return matchesAllTokens(
        haystacks: haystacks, normalizedQuery: normalizedQuery);
  }

  List<Child> get _filtered {
    return ChildrenStore.instance.children.where((c) {
      final statusMatch = _filter == _StatusFilter.all ||
          (_filter == _StatusFilter.enrolled &&
              c.enrollmentStatus == EnrollmentStatus.enrolled) ||
          (_filter == _StatusFilter.withdrawn &&
              c.enrollmentStatus == EnrollmentStatus.withdrawn);
      final queryMatch =
          _query.trim().isEmpty || _matchesQuery(c, _query.trim());
      return statusMatch && queryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final enrolledCount = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.enrolled)
        .length;
    final withdrawnCount = ChildrenStore.instance.children
        .where((c) => c.enrollmentStatus == EnrollmentStatus.withdrawn)
        .length;
    final hasChildren = ChildrenStore.instance.children.isNotEmpty;

    Widget listWidget = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Children', style: AppText.pageTitle),
              const SizedBox(height: 4),
              Text(
                'Search records and manage enrollment.',
                style: AppText.caption,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: AppText.bodyRegular,
                decoration: InputDecoration(
                  hintText: 'Search by name, guardian, or phone…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      label: 'Enrolled ($enrolledCount)',
                      selected: _filter == _StatusFilter.enrolled,
                      onTap: () =>
                          setState(() => _filter = _StatusFilter.enrolled),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: 'Withdrawn ($withdrawnCount)',
                      selected: _filter == _StatusFilter.withdrawn,
                      onTap: () =>
                          setState(() => _filter = _StatusFilter.withdrawn),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: 'All',
                      selected: _filter == _StatusFilter.all,
                      onTap: () => setState(() => _filter = _StatusFilter.all),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: MediaQuery.of(context).disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 180),
            child: KeyedSubtree(
              key: ValueKey(filtered.isEmpty),
              child: filtered.isEmpty
                  ? _EmptyState(
                      hasChildren: hasChildren,
                      hasSearch: _query.trim().isNotEmpty,
                      hasStatusFilter: _filter != _StatusFilter.all,
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _filter = _StatusFilter.all;
                        });
                      },
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                          16, 0, 16, widget.onRegister != null ? 88 : 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(),
                      itemBuilder: (context, i) {
                        final child = filtered[i];
                        final isLast = i == filtered.length - 1;
                        final primaryGuardians = child.guardians
                            .where((g) => g.isPrimary)
                            .map((g) => g.name)
                            .join(', ');
                        return InkWell(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ChildProfileScreen(child: child))),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              border: isLast
                                  ? null
                                  : const Border(
                                      bottom:
                                          BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              children: [
                                ChildAvatar(child: child, radius: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(child.fullName,
                                                style: AppText.bodyMedium,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ),
                                          if (child.enrollmentStatus ==
                                              EnrollmentStatus.withdrawn) ...[
                                            const SizedBox(width: 8),
                                            Text('withdrawn',
                                                style: AppText.monoCaption),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(child.ageLabel,
                                          style: AppText.caption),
                                      if (primaryGuardians.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(primaryGuardians,
                                            style: AppText.caption,
                                            overflow: TextOverflow.ellipsis),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right,
                                    size: 18, color: AppColors.border),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ],
    );

    if (widget.onRegister != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: FloatingActionButton.extended(
          heroTag: null,
          onPressed: widget.onRegister!,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          icon: const Icon(Icons.person_add_alt_1),
          label: Text(
            'Register child',
            style: AppText.bodyMedium.copyWith(
              color: AppColors.primaryForeground,
            ),
          ),
        ),
        body: listWidget,
      );
    }
    return listWidget;
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.foreground : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: selected ? AppColors.foreground : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      selected ? AppColors.card : AppColors.mutedForeground)),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasChildren;
  final bool hasSearch;
  final bool hasStatusFilter;
  final VoidCallback onReset;

  const _EmptyState({
    required this.hasChildren,
    required this.hasSearch,
    required this.hasStatusFilter,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasChildren) {
      return const EmptyIllustration(
        icon: Icons.child_care_outlined,
        title: 'No children yet',
        message: 'Register a child to keep their information and attendance '
            'in one place.',
      );
    }

    return EmptyIllustration(
      icon: Icons.search_off_outlined,
      title: hasSearch ? 'No matching children' : 'No children in this filter',
      message: hasSearch
          ? 'Try a different name, guardian, or phone number.'
          : 'Change the enrollment filter to see other children.',
      actionLabel: (hasSearch || hasStatusFilter) ? 'Clear filters' : null,
      onAction: (hasSearch || hasStatusFilter) ? onReset : null,
      actionIcon: Icons.filter_alt_off_outlined,
    );
  }
}
