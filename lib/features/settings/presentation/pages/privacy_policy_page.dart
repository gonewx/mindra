import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/config/app_config_service.dart';

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  String? _markdownContent;
  bool _isLoading = true;
  String? _errorMessage;
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final locale = themeProvider.locale.toString();
      final originalUrl = AppConfigService.getPrivacyPolicyUrl(locale);

      // 尝试多种方式加载内容
      String? content = await _tryLoadContent(originalUrl);

      if (content != null) {
        setState(() {
          _markdownContent = content;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load privacy policy from all sources');
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context)!;
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(e, localizations);
        });
      }
    }
  }

  /// 尝试加载内容 - 针对阿里云OSS优化
  Future<String?> _tryLoadContent(String originalUrl) async {
    final urls = _generateOssUrls(originalUrl);

    for (final url in urls) {
      try {
        debugPrint('Trying to load from: $url');

        final response = await _dio.get(
          url,
          options: Options(
            sendTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Accept': 'text/markdown, text/plain, */*',
              'User-Agent': 'Mindra-App/1.0',
            },
          ),
        );

        if (response.statusCode == 200 && response.data != null) {
          debugPrint('Successfully loaded from: $url');
          return response.data.toString();
        }
      } catch (e) {
        debugPrint('Failed to load from $url: $e');

        // 如果是最后一个URL且失败，抛出错误
        if (url == urls.last) {
          if (_isCorsError(e)) {
            throw Exception('CORS_ERROR: OSS Bucket未配置跨域访问权限，请在阿里云控制台配置CORS规则');
          }
          rethrow;
        }

        // 否则继续尝试下一个URL
        continue;
      }
    }

    return null;
  }

  /// 检查是否为CORS错误
  bool _isCorsError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('cors') ||
        errorString.contains('access-control') ||
        errorString.contains('cross-origin') ||
        (error is DioException &&
            error.type == DioExceptionType.connectionError);
  }

  /// 生成阿里云OSS的多种访问URL
  List<String> _generateOssUrls(String originalUrl) {
    final urls = <String>[];

    if (originalUrl.contains('aliyuncs.com')) {
      // 1. 原始URL（带签名）
      urls.add(originalUrl);

      // 2. 尝试移除查询参数的公开访问
      try {
        final uri = Uri.parse(originalUrl);
        final cleanUrl = '${uri.scheme}://${uri.host}${uri.path}';
        if (cleanUrl != originalUrl) {
          urls.add(cleanUrl);
        }
      } catch (e) {
        debugPrint('Failed to parse OSS URL: $e');
      }
    } else {
      // 非OSS URL，直接使用
      urls.add(originalUrl);
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.privacyPolicy,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // 如果无法pop，则导航到设置页面
              context.go('/settings');
            }
          },
        ),
      ),
      body: SafeArea(child: _buildBody(theme, themeProvider, localizations)),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    ThemeProvider themeProvider,
    AppLocalizations localizations,
  ) {
    if (_isLoading) {
      return _buildLoadingState(theme, localizations);
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, localizations);
    }

    if (_markdownContent != null) {
      return _buildMarkdownContent(theme, themeProvider);
    }

    return _buildErrorState(theme, localizations);
  }

  Widget _buildLoadingState(ThemeData theme, AppLocalizations localizations) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            localizations.privacyPolicyLoading,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, AppLocalizations localizations) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? localizations.privacyPolicyError,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            // 在调试模式下显示详细错误信息
            if (kDebugMode && _errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '调试信息:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadPrivacyPolicy,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: Text(localizations.privacyPolicyRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownContent(ThemeData theme, ThemeProvider themeProvider) {
    return Padding(
      padding: themeProvider.getResponsivePadding(context),
      child: Markdown(
        data: _markdownContent!,
        styleSheet: MarkdownStyleSheet(
          // 标题样式
          h1: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
          h2: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          h3: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
          h4: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          h5: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          h6: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          // 正文样式
          p: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.6,
          ),
          // 列表样式
          listBullet: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.6,
          ),
          // 链接样式
          a: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
          // 代码样式
          code: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          // 引用样式
          blockquote: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontStyle: FontStyle.italic,
          ),
          blockquoteDecoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 4),
            ),
          ),
          // 表格样式
          tableHead: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          tableBody: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
          tableBorder: TableBorder.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        selectable: true,
      ),
    );
  }

  /// 根据错误类型返回相应的错误消息
  String _getErrorMessage(dynamic error, AppLocalizations localizations) {
    // 调试信息
    debugPrint('Privacy policy load error: $error');
    debugPrint('Error type: ${error.runtimeType}');

    final errorString = error.toString().toLowerCase();

    // 网络连接错误
    if (errorString.contains('socketexception') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable')) {
      return localizations.privacyPolicyOffline;
    }

    // HTTP错误状态码
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return localizations.privacyPolicyOffline;
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 404) {
            return localizations.privacyPolicyNotFound;
          } else if (statusCode == 403) {
            return localizations.privacyPolicyAccessDenied;
          } else if (statusCode != null && statusCode >= 500) {
            return '${localizations.privacyPolicyServerError} ($statusCode)';
          }
          return '${localizations.privacyPolicyError} (HTTP $statusCode)';
        case DioExceptionType.cancel:
          return localizations.privacyPolicyRequestCancelled;
        case DioExceptionType.unknown:
        default:
          return localizations.privacyPolicyError;
      }
    }

    // 其他错误
    return localizations.privacyPolicyError;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
