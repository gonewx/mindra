import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/database/database_helper.dart';
import '../utils/database_test_helper.dart';

/// 数据库调试页面 - 仅用于开发调试
class DatabaseDebugPage extends StatefulWidget {
  const DatabaseDebugPage({super.key});

  @override
  State<DatabaseDebugPage> createState() => _DatabaseDebugPageState();
}

class _DatabaseDebugPageState extends State<DatabaseDebugPage> {
  Map<String, dynamic>? _debugInfo;
  List<String>? _existingFiles;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final debugInfo = await DatabaseHelper.getDatabaseDebugInfo();
      final existingFiles = await DatabaseHelper.findExistingDatabaseFiles();

      setState(() {
        _debugInfo = debugInfo;
        _existingFiles = existingFiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = {'error': e.toString()};
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据库调试信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDebugInfo,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('数据库状态', _buildDatabaseStatus()),
                  const SizedBox(height: 16),
                  _buildSection('数据统计', _buildDataStats()),
                  const SizedBox(height: 16),
                  _buildSection('存在的数据库文件', _buildExistingFiles()),
                  const SizedBox(height: 16),
                  _buildSection('测试数据管理', _buildTestDataManagement()),
                  const SizedBox(height: 16),
                  _buildSection('完整信息', _buildFullInfo()),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, Widget content) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildDatabaseStatus() {
    if (_debugInfo == null) return const Text('加载中...');

    final systemInfo = _debugInfo!['system_info'] as Map<String, dynamic>?;
    final dbPath = _debugInfo!['database_path'] ?? '未知';
    final fileExists = _debugInfo!['file_exists'] ?? false;
    final fileSize = _debugInfo!['file_size'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (systemInfo != null) ...[
          _buildInfoRow('平台', systemInfo['platform'] ?? 'Unknown'),
          _buildInfoRow('路径获取方式', systemInfo['path_method'] ?? 'Unknown'),
          if (systemInfo['follows_android_standards'] == true)
            _buildInfoRow('遵循Android标准', '✓ 是'),
          if (systemInfo['uses_context_apis'] == true)
            _buildInfoRow('使用Context API', '✓ 是'),
          if (systemInfo['avoids_hardcoded_paths'] == true)
            _buildInfoRow('避免硬编码路径', '✓ 是'),
          const SizedBox(height: 8),
        ],
        _buildInfoRow('数据库路径', dbPath, copyable: true),
        _buildInfoRow('文件存在', fileExists ? '是' : '否'),
        _buildInfoRow('文件大小', '$fileSize 字节'),
      ],
    );
  }

  Widget _buildDataStats() {
    if (_debugInfo == null) return const Text('加载中...');

    final mediaCount = _debugInfo!['media_items_count'] ?? 0;
    final sessionCount = _debugInfo!['meditation_sessions_count'] ?? 0;
    final prefCount = _debugInfo!['user_preferences_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('媒体项目数量', '$mediaCount'),
        _buildInfoRow('冥想会话数量', '$sessionCount'),
        _buildInfoRow('用户偏好数量', '$prefCount'),
      ],
    );
  }

  Widget _buildExistingFiles() {
    if (_existingFiles == null) return const Text('加载中...');
    if (_existingFiles!.isEmpty) return const Text('未找到数据库文件');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _existingFiles!
          .map(
            (file) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                file,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTestDataManagement() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ 注意：测试数据操作仅在开发模式下可用',
          style: TextStyle(
            color: Colors.orange,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _generateTestData,
                icon: const Icon(Icons.add_circle),
                label: const Text('生成测试数据'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _clearAllData,
                icon: const Icon(Icons.delete_forever),
                label: const Text('清空所有数据'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _generateTestData() async {
    try {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正在生成测试数据...')));

      await DatabaseTestHelper.generateTestData();
      await _loadDebugInfo(); // 刷新数据

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('测试数据生成成功！'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成测试数据失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _clearAllData() async {
    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空数据'),
        content: const Text('这将删除所有数据，包括媒体项目、冥想会话和用户偏好。此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('正在清空数据...')));
        }

        await DatabaseTestHelper.clearAllData();
        await _loadDebugInfo(); // 刷新数据

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('数据清空成功！'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('清空数据失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildFullInfo() {
    if (_debugInfo == null) return const Text('加载中...');

    final fullInfoText = _debugInfo.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            fullInfoText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () => _copyToClipboard(fullInfoText),
          child: const Text('复制完整信息'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: copyable ? () => _copyToClipboard(value) : null,
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: copyable ? 'monospace' : null,
                  fontSize: copyable ? 12 : null,
                  color: copyable ? Colors.blue : null,
                  decoration: copyable ? TextDecoration.underline : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
