import 'package:flutter/material.dart';
import '../models/child.dart';
import '../data/children_store.dart';
import '../data/search_utils.dart';
import '../theme/app_theme.dart';
import 'child_profile_screen.dart';

enum _StatusFilter { enrolled, withdrawn, all }

class ChildrenScreen extends StatefulWidget {
  const ChildrenScreen({super.key});

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
      haystacks: haystacks,
      normalizedQuery: normalizedQuery,
    );
  }

  List<Child> get _filtered {
    return ChildrenStore.instance.children.where((c) {
      final statusMatch = _filter == _StatusFilter.all ||
          (_filter == _StatusFilter.enrolled &&
              c.enrollmentStatus == EnrollmentStatus.enrolled) ||
          (_filter == _StatusFilter.withdrawn &&
              c.enrollmentStatus == EnrollmentStatus.withdrawn);
      final queryMatch = _query.trim().isEmpty || _matchesQuery(c, _query.trim());
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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Children', style: AppText.pageTitle),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 18, color: AppColors.mutedForeground),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _query = v),
                        style: AppText.bodyRegular,
                        decoration: InputDecoration(
                          hintText: 'Search by name, guardian, or phone…',
                          hintStyle: AppText.caption,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.close,
                            size: 16, color: AppColors.mutedForeground),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _FilterPill(
                    label: 'Enrolled ($enrolledCount)',
                    selected: _filter == _StatusFilter.enrolled,
                    onTap: () =>
                        setState(() => _filter = _StatusFilter.enrolled),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Withdrawn ($withdrawnCount)',
                    selected: _filter == _StatusFilter.withdrawn,
                    onTap: () =>
                        setState(() => _filter = _StatusFilter.withdrawn),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'All',
                    selected: _filter == _StatusFilter.all,
                    onTap: () => setState(() => _filter = _StatusFilter.all),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: 1,
                  separatorBuilder: (_, __) => const SizedBox(),
                  itemBuilder: (context, _) {
                    return Container(
                      decoration: cardDecoration(),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: List.generate(filtered.length, (i) {
                          final child = filtered[i];
                          final isLast = i == filtered.length - 1;
                          final primaryGuardians = child.guardians
                              .where((g) => g.isPrimary)
                              .map((g) => g.name)
                              .join(', ');

                          return InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ChildProfileScreen(child: child),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                border: isLast
                                    ? null
                                    : const Border(
                                        bottom: BorderSide(
                                            color: AppColors.border)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppColors.primary,
                                    child: Text(
                                      child.initials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                child.fullName,
                                                style: AppText.bodyMedium,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
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
                                        Text(
                                          child.ageLabel,
                                          style: AppText.caption,
                                        ),
                                        if (primaryGuardians.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            primaryGuardians,
                                            style: AppText.caption,
                                            overflow: TextOverflow.ellipsis,
                                          ),
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
                        }),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.foreground : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: selected ? AppColors.foreground : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.card : AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text('No results', style: AppText.bodyMedium),
            const SizedBox(height: 4),
            Text('Try a different name, guardian, or phone number',
                style: AppText.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
