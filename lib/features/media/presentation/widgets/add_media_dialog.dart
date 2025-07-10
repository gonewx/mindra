import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/media_item.dart';
import '../bloc/media_bloc.dart';
import '../bloc/media_event.dart';
import '../../../../core/constants/app_constants.dart';

class AddMediaDialog extends StatefulWidget {
  final MediaItem? editingMedia; // 如果不为null，则为编辑模式

  const AddMediaDialog({super.key, this.editingMedia});

  @override
  State<AddMediaDialog> createState() => _AddMediaDialogState();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MediaBloc>(),
        child: const AddMediaDialog(),
      ),
    );
  }

  static Future<void> showEdit(BuildContext context, MediaItem mediaItem) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MediaBloc>(),
        child: AddMediaDialog(editingMedia: mediaItem),
      ),
    );
  }
}

class _AddMediaDialogState extends State<AddMediaDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlController = TextEditingController();
  final _thumbnailController = TextEditingController();
  String _selectedCategory = AppConstants.defaultCategories.first;
  bool _isFromFile = true;
  String? _selectedFilePath;
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  final List<String> _categories = AppConstants.defaultCategories;

  bool get _isEditMode => widget.editingMedia != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _initializeForEdit();
    }
  }

  void _initializeForEdit() {
    final media = widget.editingMedia!;
    _titleController.text = media.title;
    _descriptionController.text = media.description ?? '';
    _thumbnailController.text = media.thumbnailPath ?? '';
    _selectedCategory = media.category;

    // 编辑模式下，如果有sourceUrl则显示为URL模式，否则为文件模式
    if (media.sourceUrl != null && media.sourceUrl!.isNotEmpty) {
      _isFromFile = false;
      _urlController.text = media.sourceUrl!;
    } else {
      _isFromFile = true;
      _selectedFilePath = media.filePath;
      _selectedFileName = media.filePath.split('/').last;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _urlController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A3441) : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A3441)
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? '编辑媒体信息' : '添加冥想素材',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: isDark
                          ? const Color(0xFF32B8C6)
                          : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: isDark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(shape: const CircleBorder()),
                  ),
                ],
              ),
            ),

            // Content area with scroll
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // const SizedBox(height: 20),

                    // Add source selection header (隐藏在编辑模式下)
                    if (!_isEditMode) ...[
                      Text(
                        '添加方式',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Source Selection
                      Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E2329)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _isFromFile = true),
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isFromFile
                                        ? (isDark
                                              ? const Color(0xFF32B8C6)
                                              : theme.colorScheme.primary)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.file_upload_outlined,
                                        color: _isFromFile
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white70
                                                  : theme
                                                        .colorScheme
                                                        .onSurface),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '本地导入',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: _isFromFile
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : theme
                                                              .colorScheme
                                                              .onSurface),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 48,
                              color: isDark
                                  ? const Color(0xFF3A3F47)
                                  : theme.colorScheme.outline.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    setState(() => _isFromFile = false),
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(12),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !_isFromFile
                                        ? (isDark
                                              ? const Color(0xFF32B8C6)
                                              : theme.colorScheme.primary)
                                        : Colors.transparent,
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.link,
                                        color: !_isFromFile
                                            ? Colors.white
                                            : (isDark
                                                  ? Colors.white70
                                                  : theme
                                                        .colorScheme
                                                        .onSurface),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '网络链接',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: !_isFromFile
                                                  ? Colors.white
                                                  : (isDark
                                                        ? Colors.white70
                                                        : theme
                                                              .colorScheme
                                                              .onSurface),
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // File/URL Input (隐藏在编辑模式下)
                    if (!_isEditMode && _isFromFile) ...[
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('选择文件'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.primary,
                          ),
                          foregroundColor: isDark
                              ? Colors.white70
                              : theme.colorScheme.primary,
                          backgroundColor: isDark
                              ? const Color(0xFF1E2329)
                              : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      if (_selectedFileName != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF32B8C6).withValues(alpha: 0.1)
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.1,
                                  ),
                            border: Border.all(
                              color: isDark
                                  ? const Color(
                                      0xFF32B8C6,
                                    ).withValues(alpha: 0.3)
                                  : theme.colorScheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.audio_file_outlined,
                                color: isDark
                                    ? const Color(0xFF32B8C6)
                                    : theme.colorScheme.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '已选择文件',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: isDark
                                                ? const Color(0xFF32B8C6)
                                                : theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedFileName!,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: isDark
                                                ? Colors.white
                                                : theme.colorScheme.onSurface,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.close,
                                  color: isDark
                                      ? Colors.white70
                                      : theme.colorScheme.onSurface,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _selectedFileName = null;
                                    _selectedFilePath = null;
                                    _selectedFileBytes = null;
                                  });
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? const Color(0xFF1E2329)
                                      : theme.colorScheme.surface,
                                  shape: const CircleBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else if (!_isEditMode)
                      TextField(
                        controller: _urlController,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          labelText: '媒体链接',
                          labelStyle: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                          ),
                          hintText: '请输入音频或视频的网络链接',
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white54
                                : theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1E2329)
                              : theme.colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3A3F47)
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF3A3F47)
                                  : theme.colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? const Color(0xFF32B8C6)
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          prefixIcon: Icon(
                            Icons.link,
                            color: isDark
                                ? Colors.white70
                                : theme.colorScheme.onSurface,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                      ),
                    // const SizedBox(height: 20),

                    // Title
                    Text(
                      '标题',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入素材标题',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF32B8C6)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration
                    Text(
                      '时长',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '例如：10分钟',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF32B8C6)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    Text(
                      '分类',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF3A3F47)
                              : theme.colorScheme.outline,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                        dropdownColor: isDark ? const Color(0xFF2A3441) : null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      '描述',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入描述',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF32B8C6)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Thumbnail URL
                    Text(
                      '封面图片',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _thumbnailController,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: '请输入封面图片链接（可选）',
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.white54
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF1E2329)
                            : theme.colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF3A3F47)
                                : theme.colorScheme.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF32B8C6)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        prefixIcon: Icon(
                          Icons.image,
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurface,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Fixed Actions at bottom
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2A3441)
                    : theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? const Color(0xFF3A3F47)
                        : theme.colorScheme.outline.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF3A3F47)
                              : theme.colorScheme.outline,
                        ),
                        foregroundColor: isDark
                            ? Colors.white70
                            : theme.colorScheme.onSurface,
                        backgroundColor: isDark
                            ? const Color(0xFF1E2329)
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isEditMode ? _updateMedia : _addMedia,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: isDark
                            ? const Color(0xFF32B8C6)
                            : theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(_isEditMode ? '更新' : '保存'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          // Audio formats
          'mp3', 'aac', 'wav', 'flac', 'm4a', 'ogg',
          // Video formats
          'mp4', 'mov', 'avi', 'mkv', 'webm',
        ],
        withData: kIsWeb, // On web, get file bytes
      );

      if (result != null) {
        final file = result.files.first;
        setState(() {
          _titleController.text = file.name.split('.').first;
          _selectedFileName = file.name;

          if (kIsWeb) {
            // On web, use file bytes and a placeholder path
            _selectedFileBytes = file.bytes;
            _selectedFilePath = 'web://files/${file.name}';
            debugPrint(
              'Web file selected: ${file.name}, bytes: ${file.bytes?.length ?? 0}',
            );
          } else {
            // On other platforms, use the actual file path
            _selectedFilePath = file.path;
            debugPrint('Desktop file selected: ${file.path}');
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已选择文件: ${file.name}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('文件选择失败: ${e.toString()}')));
      }
    }
  }

  void _addMedia() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }

    if (_isFromFile && _selectedFilePath == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择文件')));
      return;
    }

    if (!_isFromFile && _urlController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入媒体链接')));
      return;
    }

    // Determine media type based on file extension or URL
    MediaType mediaType = MediaType.audio;
    final filePath = _isFromFile ? _selectedFilePath! : _urlController.text;
    final extension = filePath.split('.').last.toLowerCase();

    if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
      mediaType = MediaType.video;
    }

    // Add media item using BLoC
    debugPrint(
      'Adding media item - Title: ${_titleController.text}, FilePath: $filePath, FileBytes: ${kIsWeb && _isFromFile ? _selectedFileBytes?.length ?? 0 : 'N/A'}',
    );

    context.read<MediaBloc>().add(
      AddMediaItem(
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        filePath: filePath,
        category: _selectedCategory,
        sourceUrl: _isFromFile ? null : _urlController.text,
        type: mediaType,
        fileBytes: kIsWeb && _isFromFile
            ? _selectedFileBytes
            : null, // Pass file bytes for web
      ),
    );

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('素材添加成功')));
  }

  void _updateMedia() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }

    final updatedMedia = widget.editingMedia!.copyWith(
      title: _titleController.text,
      description: _descriptionController.text.isEmpty
          ? null
          : _descriptionController.text,
      category: _selectedCategory,
      thumbnailPath: _thumbnailController.text.isEmpty
          ? null
          : _thumbnailController.text,
    );

    // Update media item using BLoC
    context.read<MediaBloc>().add(UpdateMediaItem(updatedMedia));

    Navigator.pop(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('媒体信息更新成功')));
  }
}
