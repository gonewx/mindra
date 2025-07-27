import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import '../../../../shared/widgets/animated_media_card.dart';
import '../widgets/add_media_dialog.dart';
import '../bloc/media_bloc.dart';
import '../bloc/media_event.dart';
import '../bloc/media_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/media_item.dart';
import '../../../../core/constants/media_category.dart';
import '../../data/datasources/media_local_datasource.dart';
import '../../domain/services/media_library_settings_service.dart';
import '../../../../core/database/database_helper.dart';

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
  bool _isBatchDeleteMode = false;
  bool _isDragSortMode = false;
  final Set<String> _selectedForDelete = {};
  final TextEditingController _searchController = TextEditingController();

  List<String> get _categories {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return ['All'];
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

  // 将显示名称映射到枚举名称
  String _getCategoryEnumName(String displayName) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return displayName;
    }

    if (displayName == localizations.mediaLibraryCategoryAll) {
      return '全部'; // 特殊处理"全部"分类
    } else if (displayName == localizations.categoryNameMeditation) {
      return 'meditation';
    } else if (displayName == localizations.categoryNameBedtime) {
      return 'sleep';
    } else if (displayName == localizations.categoryNameFocus) {
      return 'focus';
    } else if (displayName == localizations.categoryNameRelax) {
      return 'relaxation';
    } else if (displayName == localizations.categoryNameNatureSounds) {
      return 'nature';
    }

    return displayName; // 默认返回原始名称
  }

  @override
  void initState() {
    super.initState();
    // 加载保存的视图模式
    _loadViewMode();
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

  // 加载保存的视图模式
  Future<void> _loadViewMode() async {
    final savedViewMode = await MediaLibrarySettingsService.getViewMode();
    if (mounted) {
      setState(() {
        _isGridView = savedViewMode;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildNormalHeader() {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          AppLocalizations.of(context)?.mediaLibraryTitle ?? 'Media Library',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // 拖动排序按钮（仅在列表视图时显示）
            if (!_isGridView)
              IconButton(
                onPressed: _toggleDragSortMode,
                icon: Icon(
                  Icons.swap_vert,
                  color: _isDragSortMode ? theme.colorScheme.primary : null,
                ),
                tooltip: _isDragSortMode ? '退出排序模式' : '排序模式',
              ),
            // 批量删除按钮
            IconButton(
              onPressed: _enterBatchDeleteMode,
              icon: const Icon(Icons.delete_sweep),
              tooltip: '批量删除',
            ),
            const SizedBox(width: 8),
            // 添加素材按钮
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary,
              ),
              child: IconButton(
                onPressed: _showAddMediaDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                tooltip: '添加素材',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBatchDeleteHeader() {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Row(
      children: [
        IconButton(
          onPressed: _exitBatchDeleteMode,
          icon: const Icon(Icons.close),
          tooltip: '取消',
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            '已选择 ${_selectedForDelete.length} 项',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_selectedForDelete.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _deleteSelectedItems,
            icon: const Icon(Icons.delete),
            label: Text(localizations.delete),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
          ),
      ],
    );
  }

  Widget _buildDragSortHeader() {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          onPressed: _exitDragSortMode,
          icon: const Icon(Icons.close),
          tooltip: '退出排序模式',
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.swap_vert,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '拖动排序模式',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '长按并拖动项目以调整顺序',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _enterBatchDeleteMode() {
    setState(() {
      _isBatchDeleteMode = true;
      _selectedForDelete.clear();
    });
  }

  void _exitBatchDeleteMode() {
    setState(() {
      _isBatchDeleteMode = false;
      _selectedForDelete.clear();
    });
  }

  void _toggleDragSortMode() {
    setState(() {
      _isDragSortMode = !_isDragSortMode;
      // 退出其他模式
      if (_isDragSortMode) {
        _isBatchDeleteMode = false;
        _selectedForDelete.clear();
      }
    });
  }

  void _exitDragSortMode() {
    setState(() {
      _isDragSortMode = false;
    });
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
            child: _isDragSortMode
                ? _buildDragSortHeader()
                : _isBatchDeleteMode
                ? _buildBatchDeleteHeader()
                : _buildNormalHeader(),
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
                        hintText:
                            AppLocalizations.of(
                              context,
                            )?.mediaLibrarySearchHint ??
                            'Search meditation materials...',
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
                    onTap: () => _toggleViewMode(),
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
                        // 使用枚举名称进行查询
                        final enumName = _getCategoryEnumName(category);
                        context.read<MediaBloc>().add(
                          LoadMediaItemsByCategory(enumName),
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
                Text(
                  AppLocalizations.of(context)?.mediaLibraryLoadFailed ??
                      'Load Failed',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  state.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // 使用枚举名称进行查询
                    final enumName = _getCategoryEnumName(_selectedCategory);
                    context.read<MediaBloc>().add(
                      LoadMediaItemsByCategory(enumName),
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)?.mediaLibraryRetry ?? 'Retry',
                  ),
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
                  Text(
                    AppLocalizations.of(context)?.mediaLibraryNoMaterials ??
                        'No Materials',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(
                          context,
                        )?.mediaLibraryAddMaterialsHint ??
                        'Click the top-right button to add materials',
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

  Widget _buildGridView(List<MediaItem> mediaItems) {
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

        // 网格视图暂不支持拖动排序，显示提示
        return Stack(
          children: [
            GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsiveCrossAxisCount,
                childAspectRatio: responsiveChildAspectRatio,
                crossAxisSpacing: effectiveSpacing,
                mainAxisSpacing: effectiveSpacing,
              ),
              itemCount: mediaItems.length,
              itemBuilder: (context, index) {
                try {
                  final item = mediaItems[index];
                  return _buildMediaCard(item, false, allItems: mediaItems);
                } catch (e) {
                  // 如果单个项目渲染失败，显示错误占位符
                  return _buildErrorCard('项目渲染失败');
                }
              },
            ),
            if (!_isBatchDeleteMode)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      '切换到列表视图以使用拖动排序',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildListView(List<MediaItem> mediaItems) {
    // 在批量删除模式或非拖动模式下使用普通ListView
    if (_isBatchDeleteMode || !_isDragSortMode) {
      return ListView.builder(
        itemCount: mediaItems.length,
        itemBuilder: (context, index) {
          try {
            final item = mediaItems[index];
            return Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildMediaCard(item, true, allItems: mediaItems),
            );
          } catch (e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildErrorCard('项目渲染失败'),
            );
          }
        },
      );
    }

    // 拖动排序模式下使用ReorderableListView
    return ReorderableListView.builder(
      itemCount: mediaItems.length,
      onReorder: (oldIndex, newIndex) =>
          _handleReorder(mediaItems, oldIndex, newIndex),
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            return Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              shadowColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.3),
              child: child,
            );
          },
          child: child,
        );
      },
      itemBuilder: (context, index) {
        try {
          final item = mediaItems[index];
          return Padding(
            key: ValueKey(item.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildMediaCard(item, true, allItems: mediaItems),
          );
        } catch (e) {
          return Container(
            key: ValueKey('error_$index'),
            padding: const EdgeInsets.only(bottom: 8),
            child: _buildErrorCard('项目渲染失败'),
          );
        }
      },
    );
  }

  Widget _buildMediaCard(
    MediaItem item,
    bool isListView, {
    List<MediaItem>? allItems,
  }) {
    try {
      // 安全地格式化时长
      String formattedDuration = '0:00';
      if (item.duration > 0) {
        final minutes = item.duration ~/ 60;
        final seconds = item.duration % 60;
        formattedDuration = '$minutes:${seconds.toString().padLeft(2, '0')}';
      }

      // 安全地获取分类显示名称
      String categoryDisplayName = '未知分类';
      try {
        categoryDisplayName = item.category.getDisplayName(context);
      } catch (e) {
        // 如果获取分类名称失败，使用默认值
        categoryDisplayName = item.category.name;
      }

      if (_isBatchDeleteMode) {
        // 批量删除模式下的卡片
        final isSelected = _selectedForDelete.contains(item.id);

        return GestureDetector(
          onTap: () => _toggleDeleteSelection(item.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.error
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                AnimatedMediaCard(
                  title: item.title.isNotEmpty ? item.title : '未命名',
                  duration: formattedDuration,
                  category: categoryDisplayName,
                  isListView: isListView,
                  onTap: () => _toggleDeleteSelection(item.id),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Theme.of(context).colorScheme.error
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // 正常模式下的卡片
        if (isListView && allItems != null) {
          // 拖动排序模式
          if (_isDragSortMode) {
            return Row(
              children: [
                // 拖动手柄图标
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                // 媒体卡片（禁用点击）
                Expanded(
                  child: AnimatedMediaCard(
                    title: item.title.isNotEmpty ? item.title : '未命名',
                    duration: formattedDuration,
                    category: categoryDisplayName,
                    isListView: isListView,
                    onTap: null, // 拖动模式下禁用点击
                  ),
                ),
              ],
            );
          } else {
            // 正常列表视图：支持所有交互
            return GestureDetector(
              onTap: () => _playMedia(item.id),
              onLongPress: () => _showMediaContextMenu(context, item),
              onSecondaryTapDown: (details) => _showMediaContextMenu(
                context,
                item,
                position: details.globalPosition,
              ),
              child: AnimatedMediaCard(
                title: item.title.isNotEmpty ? item.title : '未命名',
                duration: formattedDuration,
                category: categoryDisplayName,
                isListView: isListView,
                onTap: () => _playMedia(item.id),
              ),
            );
          }
        } else {
          // 网格视图：保留长按菜单
          return GestureDetector(
            onTap: () => _playMedia(item.id),
            onLongPress: () => _showMediaContextMenu(context, item),
            onSecondaryTapDown: (details) => _showMediaContextMenu(
              context,
              item,
              position: details.globalPosition,
            ),
            child: AnimatedMediaCard(
              title: item.title.isNotEmpty ? item.title : '未命名',
              duration: formattedDuration,
              category: categoryDisplayName,
              isListView: isListView,
              onTap: () => _playMedia(item.id),
            ),
          );
        }
      }
    } catch (e) {
      return _buildErrorCard('卡片渲染失败');
    }
  }

  void _toggleDeleteSelection(String itemId) {
    setState(() {
      if (_selectedForDelete.contains(itemId)) {
        _selectedForDelete.remove(itemId);
      } else {
        _selectedForDelete.add(itemId);
      }
    });
  }

  // 显示媒体上下文菜单（右键菜单或长按菜单）
  void _showMediaContextMenu(
    BuildContext context,
    MediaItem item, {
    Offset? position,
  }) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final localizations = AppLocalizations.of(context)!;

    showMenu(
      context: context,
      position: position != null
          ? RelativeRect.fromLTRB(
              position.dx,
              position.dy,
              overlay.size.width - position.dx,
              overlay.size.height - position.dy,
            )
          : RelativeRect.fromLTRB(100, 100, 100, 100), // 长按时的默认位置
      items: [
        PopupMenuItem(
          value: 'play',
          child: ListTile(
            leading: const Icon(Icons.play_arrow),
            title: Text(localizations.play),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: const Icon(Icons.edit),
            title: Text(localizations.actionEdit),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              localizations.delete,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        _handleContextMenuAction(value, item);
      }
    });
  }

  // 处理上下文菜单操作
  void _handleContextMenuAction(String action, MediaItem item) {
    switch (action) {
      case 'play':
        _playMedia(item.id);
        break;
      case 'edit':
        _editSingleItem(item);
        break;
      case 'delete':
        _deleteSingleItem(item);
        break;
    }
  }

  // 编辑单个素材
  void _editSingleItem(MediaItem item) async {
    try {
      if (mounted) {
        AddMediaDialog.showEdit(context, item).then((_) {
          // 刷新列表
          _refreshMediaList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法编辑媒体项: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  // 删除单个素材
  void _deleteSingleItem(MediaItem item) async {
    final localizations = AppLocalizations.of(context)!;

    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirmDelete),
        content: Text('确定要删除素材"${item.title}"吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dataSource = GetIt.instance<MediaLocalDataSource>();
      await dataSource.deleteMediaItem(item.id);

      _refreshMediaList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除素材"${item.title}"'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Widget _buildErrorCard(String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(color: Colors.red),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMediaDialog() {
    try {
      AddMediaDialog.show(context)
          .then((_) {
            // Refresh media list after adding
            if (mounted) {
              context.read<MediaBloc>().add(
                LoadMediaItemsByCategory(_selectedCategory),
              );
            }
          })
          .catchError((error) {
            // 处理对话框错误
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('添加媒体对话框错误：$error'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            }
          });
    } catch (e) {
      // 处理显示对话框时的错误
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法打开添加媒体对话框：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _playMedia(String mediaId) {
    try {
      if (mediaId.isEmpty) {
        throw ArgumentError('Media ID cannot be empty');
      }

      context.go('${AppRouter.player}?mediaId=$mediaId');
    } catch (e) {
      // 处理导航错误
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('无法播放媒体：$e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _deleteSelectedItems() async {
    if (_selectedForDelete.isEmpty) return;

    final localizations = AppLocalizations.of(context)!;

    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.confirmDelete),
        content: Text(
          localizations.deleteConfirmMessage(_selectedForDelete.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dataSource = GetIt.instance<MediaLocalDataSource>();

      // 删除选中的项目
      for (final itemId in _selectedForDelete) {
        await dataSource.deleteMediaItem(itemId);
      }

      // 刷新列表
      _refreshMediaList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.deleteSuccessMessage(_selectedForDelete.length),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      _exitBatchDeleteMode();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _refreshMediaList() {
    final enumName = _getCategoryEnumName(_selectedCategory);
    context.read<MediaBloc>().add(LoadMediaItemsByCategory(enumName));
  }

  // 切换视图模式并保存
  Future<void> _toggleViewMode() async {
    setState(() {
      _isGridView = !_isGridView;
      // 切换到网格视图时自动退出拖动模式
      if (_isGridView) {
        _isDragSortMode = false;
      }
    });
    await MediaLibrarySettingsService.setViewMode(_isGridView);
  }

  // 处理拖动排序
  Future<void> _handleReorder(
    List<MediaItem> mediaItems,
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 创建新的排序列表
    final List<MediaItem> reorderedItems = List.from(mediaItems);
    final item = reorderedItems.removeAt(oldIndex);
    reorderedItems.insert(newIndex, item);

    // 获取新的ID顺序
    final List<String> newOrder = reorderedItems
        .map((item) => item.id)
        .toList();

    try {
      // 更新数据库中的排序
      await DatabaseHelper.updateMediaItemsSortOrder(newOrder);

      // 保存排序顺序到设置
      await MediaLibrarySettingsService.setSortOrder(newOrder);

      // 刷新列表以应用新排序
      _refreshMediaList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('排序已更新'),
            duration: const Duration(seconds: 1),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('排序失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
