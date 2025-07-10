import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/animated_media_card.dart';
import '../widgets/add_media_dialog.dart';
import '../bloc/media_bloc.dart';
import '../bloc/media_event.dart';
import '../bloc/media_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  @override
  Widget build(BuildContext context) {
    return const _MediaLibraryView();
  }
}

class _MediaLibraryView extends StatefulWidget {
  const _MediaLibraryView();

  @override
  State<_MediaLibraryView> createState() => _MediaLibraryViewState();
}

class _MediaLibraryViewState extends State<_MediaLibraryView> {
  String _selectedCategory = 'All';
  bool _isGridView = true;
  final TextEditingController _searchController = TextEditingController();

  List<String> get _categories {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return ['All', ...AppConstants.defaultCategories];
    }
    
    return [
      localizations.mediaLibraryCategoryAll,
      localizations.categoryNameMeditation,
      localizations.categoryNameBedtime,
      localizations.categoryNameFocus,
      localizations.categoryNameRelax,
      localizations.categoryNameNatureSounds,
    ];
  }

  @override
  void initState() {
    super.initState();
    // 在下一帧触发加载事件，确保context已经完全初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 设置默认分类为本地化的"全部"
        final localizations = AppLocalizations.of(context);
        _selectedCategory = localizations?.mediaLibraryCategoryAll ?? 'All';
        context.read<MediaBloc>().add(LoadMediaItems());
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)?.mediaLibraryTitle ?? 'Media Library',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primary,
                  ),
                  child: IconButton(
                    onPressed: _showAddMediaDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar with View Toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.mediaLibrarySearchHint ?? 'Search meditation materials...',
                        hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        // TODO: Implement search
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // View Toggle Button
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Icon(
                        _isGridView
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.8,
                        ),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Category Tabs
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click, // 添加手形光标
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                        });
                        context.read<MediaBloc>().add(
                          LoadMediaItemsByCategory(category),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(
                                    alpha: 0.2,
                                  ),
                          ),
                        ),
                        child: Text(
                          category,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Content
          Expanded(child: _buildMediaList()),
        ],
      ),
    );
  }

  Widget _buildMediaList() {
    return BlocBuilder<MediaBloc, MediaState>(
      builder: (context, state) {
        if (state is MediaLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is MediaError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)?.mediaLibraryLoadFailed ?? 'Load Failed', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<MediaBloc>().add(
                      LoadMediaItemsByCategory(_selectedCategory),
                    );
                  },
                  child: Text(AppLocalizations.of(context)?.mediaLibraryRetry ?? 'Retry'),
                ),
              ],
            ),
          );
        } else if (state is MediaLoaded) {
          final mediaItems = state.mediaItems;

          if (mediaItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.library_music_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(AppLocalizations.of(context)?.mediaLibraryNoMaterials ?? 'No Materials', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.mediaLibraryAddMaterialsHint ?? 'Click the top-right button to add materials',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _isGridView
                ? _buildGridView(mediaItems)
                : _buildListView(mediaItems),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildGridView(List<dynamic> mediaItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 响应式设计：根据屏幕宽度计算列数和间距
        final screenWidth = constraints.maxWidth;
        const effectiveSpacing = 16.0;

        // 计算响应式列数
        int responsiveCrossAxisCount;
        if (screenWidth < 600) {
          responsiveCrossAxisCount = 2; // 小屏幕 2 列
        } else if (screenWidth < 900) {
          responsiveCrossAxisCount = 3; // 中屏幕 3 列
        } else if (screenWidth < 1200) {
          responsiveCrossAxisCount = 4; // 大屏幕 4 列
        } else {
          responsiveCrossAxisCount = 5; // 超大屏幕 5 列
        }

        // 计算响应式宽高比
        double responsiveChildAspectRatio;
        if (screenWidth < 600) {
          responsiveChildAspectRatio = 0.75; // 小屏幕保持原比例
        } else {
          responsiveChildAspectRatio = 1.0; // 大屏幕使用更方正的比例
        }

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: responsiveCrossAxisCount,
            childAspectRatio: responsiveChildAspectRatio,
            crossAxisSpacing: effectiveSpacing,
            mainAxisSpacing: effectiveSpacing,
          ),
          itemCount: mediaItems.length,
          itemBuilder: (context, index) {
            final item = mediaItems[index];
            return AnimatedMediaCard(
              title: item.title,
              duration:
                  '${item.duration ~/ 60}:${(item.duration % 60).toString().padLeft(2, '0')}',
              category: item.category,
              isListView: false,
              onTap: () => _playMedia(item.id),
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<dynamic> mediaItems) {
    return ListView.builder(
      itemCount: mediaItems.length,
      itemBuilder: (context, index) {
        final item = mediaItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AnimatedMediaCard(
            title: item.title,
            duration:
                '${item.duration ~/ 60}:${(item.duration % 60).toString().padLeft(2, '0')}',
            category: item.category,
            isListView: true,
            onTap: () => _playMedia(item.id),
          ),
        );
      },
    );
  }

  void _showAddMediaDialog() {
    AddMediaDialog.show(context).then((_) {
      // Refresh media list after adding
      if (mounted) {
        context.read<MediaBloc>().add(
          LoadMediaItemsByCategory(_selectedCategory),
        );
      }
    });
  }

  void _playMedia(String mediaId) {
    context.go('${AppRouter.player}?mediaId=$mediaId');
  }
}
