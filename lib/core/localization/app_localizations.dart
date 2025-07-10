import 'package:flutter/material.dart';

class AppLocalizations {
  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'personal_center': 'Personal Center',
      'meditator': 'Meditator',
      'meditated_times': 'Meditated {count} times',
      'personalization_settings': 'Personalization Settings',
      'theme_settings': 'Theme Settings',
      'language_settings': 'Language Settings',
      'notification_settings': 'Notification Settings',
      'card_spacing': 'Card Spacing',
      'card_padding': 'Card Padding',
      'app_settings': 'App Settings',
      'privacy_settings': 'Privacy Settings',
      'storage_management': 'Storage Management',
      'about': 'About',
      'about_app': 'About App',
      'select_theme': 'Select Theme',
      'select_language': 'Select Language',
      'simplified_chinese': 'Simplified Chinese',
      'english': 'English',
      'notification_settings_title': 'Notification Settings',
      'push_notifications': 'Push Notifications',
      'push_notifications_desc': 'Allow app to send push notifications',
      'daily_reminder': 'Daily Reminder',
      'daily_reminder_desc': 'Daily meditation reminder',
      'session_reminder': 'Session Reminder',
      'session_reminder_desc': 'End of meditation session reminder',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'notification_settings_saved': 'Notification settings saved',
      'adjust_card_spacing': 'Adjust Card Spacing',
      'current_spacing': 'Current spacing: {value}px',
      'compact_8px': 'Compact (8px)',
      'loose_32px': 'Loose (32px)',
      'card_spacing_set': 'Card spacing set to {value}px',
      'adjust_card_padding': 'Adjust Card Padding',
      'current_padding': 'Current padding: {value}px',
      'compact_12px': 'Compact (12px)',
      'card_padding_set': 'Card padding set to {value}px',
      'coming_soon': 'Coming Soon',
      'coming_soon_desc': 'This feature is under development, stay tuned.',
      'got_it': 'Got It',
      'home': 'Home',
      'media_library': 'Media Library',
      'play': 'Play',
      'progress': 'Progress',
      'profile': 'Profile',
      'page_not_found': 'Page Not Found',
      'page_not_found_desc': 'Please check the link or return to home',
      'back_to_home': 'Back to Home',
      'good_morning': 'Good Morning!',
      'good_afternoon': 'Good Afternoon!',
      'good_evening': 'Good Evening!',
      'ready_to_start_meditation': 'Ready to start today\'s meditation journey?',
      'recent_sessions': 'Recent Sessions',
      // Player
      'player_initialization_failed': 'Player initialization failed: {error}',
      'player_now_playing': 'Now Playing',
      'player_no_material_selected': 'No Material Selected',
      'player_select_material_message': 'Please select an audio or video material from the media library first',
      'player_shuffle_enabled': 'Shuffle enabled',
      'player_shuffle_disabled': 'Shuffle disabled',
      'player_repeat_mode': 'Repeat mode: {mode}',
      'player_reload_media_data': 'Reload media data to get updated information',
      // Categories
      'category_meditation': 'Meditation',
      'category_mindfulness': 'Mindfulness',
      'category_bedtime': 'Bedtime',
      'category_sleep': 'Sleep',
      'category_focus': 'Focus',
      'category_study': 'Study',
      'category_relax': 'Relax',
      'category_soothing': 'Soothing',
      'category_nature': 'Nature',
      'category_environment': 'Environment',
      'category_breathing': 'Breathing',
      // Meditation
      'meditation_completed': 'Meditation Completed',
      'meditation_congratulations': 'Congratulations! You have completed this meditation practice.',
      'meditation_practice_duration': 'Practice duration: {minutes} minutes',
      // Navigation
      'navigation_view_progress': 'View Progress',
      'navigation_go_to_media_library': 'Go to Media Library',
      // Actions
      'action_complete': 'Complete',
      'action_edit': 'Edit',
      'action_share': 'Share',
      'action_download': 'Download',
      'action_add_to_playlist': 'Add to Playlist',
      'action_report': 'Report',
      'action_cancel': 'Cancel',
      'action_create': 'Create',
      'action_confirm': 'Confirm',
      'action_save': 'Save',
      'action_more_options': 'More Options',
      'action_go_to_settings': 'Go to Settings',
      // Favorites
      'favorites_added': 'Added to favorites',
      'favorites_removed': 'Removed from favorites',
      // Playlist
      'playlist_my_favorites': 'My Favorites',
      'playlist_mindfulness_practice': 'Mindfulness Practice',
      'playlist_sleep_album': 'Sleep Album',
      'playlist_create_new': 'Create New Playlist',
      'playlist_create_playlist': 'Create Playlist',
      'playlist_name_label': 'Playlist Name',
      'playlist_name_hint': 'Enter playlist name',
      'playlist_added_to_playlist': 'Added "{title}" to "{playlist}"',
      'playlist_add_media_message': 'Add "{title}" to:',
      // Download
      'download_confirm_message': 'Download "{title}" to local storage?',
      'download_warning': 'Note: This feature requires internet connection and will consume storage space.',
      'download_start': 'Start Download',
      'download_downloading': 'Downloading "{title}"...',
      'download_completed': 'Download completed: {title}',
      // Share
      'share_listening_to': 'Listening to: {title}',
      'share_category': 'Category: {category}',
      'share_description': 'Description: {description}',
      'share_app_signature': 'From Mindra Meditation App',
      'share_copied_to_clipboard': 'Share content copied to clipboard',
      // Timer
      'timer_settings': 'Timer Settings',
      'timer_minutes_after': '{minutes} minutes later',
      'timer_set_message': 'Set {minutes} minutes timer stop',
      'timer_cancel': 'Cancel Timer',
      'timer_cancelled': 'Timer stop cancelled',
      // Sound Effects
      'sound_effects_settings': 'Sound Effects Settings',
      'sound_effects_rain': 'Rain',
      'sound_effects_ocean': 'Ocean',
      'sound_effects_wind_chimes': 'Wind Chimes',
      'sound_effects_birds': 'Birds',
      'sound_effects_loading': 'Loading sound effects...',
      'sound_effects_background_title': 'Background Sound Effects',
      'sound_effects_background_description': 'Soft background effects that won\'t interfere with main audio',
      'sound_effects_volume_control': 'Volume Control',
      'sound_effects_settings_saved': 'Background sound effects settings saved',
      'sound_effects_builtin_config': 'Built-in effect configuration',
      // Repeat Mode
      'repeat_mode_off': 'Off',
      'repeat_mode_all': 'Repeat All',
      'repeat_mode_one': 'Repeat One',
      // Audio Focus
      'audio_focus_manager_description': 'Audio focus manager - coordinates main audio and background effects playback',
      // Progress
      'progress_my_progress': 'My Progress',
      'progress_settings': 'Progress Settings',
      // Stats
      'stats_consecutive_days': 'Consecutive Days',
      'stats_weekly_duration': 'Weekly Duration',
      'stats_total_sessions': 'Total Sessions',
      'stats_weekly_meditation_duration': 'Weekly Meditation Duration',
      'stats_days_format': '{days} days',
      'stats_minutes_format': '{minutes} minutes',
      'stats_times_format': '{times} times',
      // Achievements
      'achievements_title': 'Achievement Badges',
      'achievements_first_meditation_title': 'First Timer',
      'achievements_first_meditation_description': 'Complete your first meditation session',
      'achievements_week_streak_title': '7-Day Streak',
      'achievements_week_streak_description': 'Meditate for 7 consecutive days',
      'achievements_focus_master_title': 'Focus Expert',
      'achievements_focus_master_description': 'Complete 30+ minute meditation sessions',
      'achievements_meditation_expert_title': 'Master Meditator',
      'achievements_meditation_expert_description': 'Accumulate 10 hours of meditation time',
      'achievements_consistency_champion_title': 'Consistent Soul',
      'achievements_consistency_champion_description': 'Meditate for 30 consecutive days',
      'achievements_variety_seeker_title': 'Explorer',
      'achievements_variety_seeker_description': 'Try 5 different meditation types',
      // History
      'history_meditation_history': 'Meditation History',
      // Weekdays
      'weekdays_monday': 'Mon',
      'weekdays_tuesday': 'Tue',
      'weekdays_wednesday': 'Wed',
      'weekdays_thursday': 'Thu',
      'weekdays_friday': 'Fri',
      'weekdays_saturday': 'Sat',
      'weekdays_sunday': 'Sun',
      // Calendar
      'calendar_sunday': 'Sun',
      'calendar_monday': 'Mon',
      'calendar_tuesday': 'Tue',
      'calendar_wednesday': 'Wed',
      'calendar_thursday': 'Thu',
      'calendar_friday': 'Fri',
      'calendar_saturday': 'Sat',
      // Goals
      'goals_set_goals': 'Set Goals',
      'goals_adjust_daily_goal': 'Adjust daily meditation goals',
      'goals_settings_title': 'Goal Settings',
      'goals_daily_goal': 'Daily Goal',
      'goals_weekly_goal': 'Weekly Goal',
      'goals_default_daily': '20 minutes',
      'goals_default_weekly': '7 times',
      'goals_select_label': 'Select {label}',
      'goals_invalid_format': 'Goal setting format is incorrect',
      'goals_settings_saved': 'Goal settings saved',
      'goals_save_failed': 'Save failed: {error}',
      // Reminders
      'reminders_settings': 'Reminder Settings',
      'reminders_set_reminder_time': 'Set meditation reminder time',
      'reminders_settings_title': 'Reminder Settings',
      'reminders_time': 'Reminder Time',
      'reminders_date': 'Reminder Date',
      'reminders_method': 'Reminder Method',
      'reminders_enable': 'Enable Reminders',
      'reminders_enable_description': 'Daily timed reminders for meditation',
      'reminders_time_label': 'Reminder Time',
      'reminders_select_time': 'Select Time',
      'reminders_select_dates': 'Select Reminder Dates',
      'reminders_method_label': 'Reminder Method',
      'reminders_notification': 'Notification Reminder',
      'reminders_notification_description': 'Display reminder message in notification bar',
      'reminders_sound': 'Sound Reminder',
      'reminders_sound_description': 'Play reminder sound',
      'reminders_vibration': 'Vibration Reminder',
      'reminders_vibration_description': 'Device vibration reminder',
      'reminders_settings_saved': 'Reminder settings saved',
      'reminders_disabled': 'Reminders disabled',
      'reminders_save_failed': 'Save failed: {error}',
      // Permissions
      'permissions_title': 'Permissions Required',
      'permissions_description': 'To send meditation reminders, the following permissions are required:\n\n• Notification permission - Display reminder messages\n• Exact alarm permission - Send timely reminders\n\nPlease manually enable these permissions in system settings.',
      // Session Types
      'session_types_meditation': 'Meditation',
      'session_types_breathing': 'Breathing',
      'session_types_sleep': 'Sleep',
      'session_types_focus': 'Focus',
      'session_types_relaxation': 'Relaxation',
      // Session Categories
      'session_categories_breathing_practice': 'Breathing Practice',
      'session_categories_sleep_guidance': 'Sleep Guidance',
      'session_categories_focus_training': 'Focus Training',
      'session_categories_relaxation_meditation': 'Relaxation Meditation',
      // Layout
      'layout_title_center_placeholder': 'Placeholder to keep title centered',
      'layout_reduce_spacing': 'Reduce spacing',
      // Daily Goal
      'daily_goal_title': 'Daily Goal',
      'daily_goal_meditation_suffix': ' meditation',
      'daily_goal_default': '20 minutes meditation',
      // Dialog
      'dialog_add_media_title': 'Add Meditation Material',
      'dialog_edit_media_title': 'Edit Media Information',
      'dialog_add_method': 'Add Method',
      'dialog_local_import': 'Local Import',
      'dialog_network_link': 'Network Link',
      'dialog_select_file': 'Select File',
      'dialog_file_selected': 'File Selected',
      'dialog_media_link': 'Media Link',
      'dialog_media_link_hint': 'Enter audio or video network link',
      'dialog_title': 'Title',
      'dialog_title_hint': 'Enter material title',
      'dialog_duration': 'Duration',
      'dialog_duration_hint': 'Enter duration (seconds)',
      'dialog_duration_loading': 'Getting duration...',
      'dialog_category': 'Category',
      'dialog_description': 'Description',
      'dialog_description_hint': 'Enter description',
      'dialog_thumbnail': 'Thumbnail',
      'dialog_thumbnail_hint': 'Enter thumbnail image link (optional)',
      'dialog_update': 'Update',
      'dialog_save': 'Save',
      'dialog_file_selected_success': 'File selected: {fileName}',
      'dialog_file_selection_failed': 'File selection failed: {error}',
      'dialog_title_required': 'Please enter title',
      'dialog_file_required': 'Please select file',
      'dialog_url_required': 'Please enter media link',
      'dialog_duration_invalid': 'Please enter valid duration (seconds)',
      'dialog_material_added': 'Material added successfully',
      'dialog_media_updated': 'Media information updated successfully',
    },
    'zh': {
      'personal_center': '个人中心',
      'meditator': '冥想者',
      'meditated_times': '已冥想 {count} 次',
      'personalization_settings': '个性化设置',
      'theme_settings': '主题设置',
      'language_settings': '语言设置',
      'notification_settings': '通知设置',
      'card_spacing': '卡片间距',
      'card_padding': '卡片内边距',
      'app_settings': '应用设置',
      'privacy_settings': '隐私设置',
      'storage_management': '存储管理',
      'about': '关于',
      'about_app': '关于应用',
      'select_theme': '选择主题',
      'select_language': '选择语言',
      'simplified_chinese': '简体中文',
      'english': 'English',
      'notification_settings_title': '通知设置',
      'push_notifications': '推送通知',
      'push_notifications_desc': '允许应用发送推送通知',
      'daily_reminder': '每日提醒',
      'daily_reminder_desc': '每天定时提醒冥想',
      'session_reminder': '会话提醒',
      'session_reminder_desc': '冥想会话结束提醒',
      'cancel': '取消',
      'confirm': '确定',
      'notification_settings_saved': '通知设置已保存',
      'adjust_card_spacing': '调整卡片间距',
      'current_spacing': '当前间距: {value}px',
      'compact_8px': '紧凑 (8px)',
      'loose_32px': '宽松 (32px)',
      'card_spacing_set': '卡片间距已设置为 {value}px',
      'adjust_card_padding': '调整卡片内边距',
      'current_padding': '当前内边距: {value}px',
      'compact_12px': '紧凑 (12px)',
      'card_padding_set': '卡片内边距已设置为 {value}px',
      'coming_soon': '即将推出',
      'coming_soon_desc': '此功能正在开发中，敬请期待。',
      'got_it': '知道了',
      'home': '首页',
      'media_library': '素材库',
      'play': '播放',
      'progress': '进度',
      'profile': '我的',
      'page_not_found': '页面不存在',
      'page_not_found_desc': '请检查链接或返回首页',
      'back_to_home': '返回首页',
      'good_morning': '早上好！',
      'good_afternoon': '下午好！',
      'good_evening': '晚上好！',
      'ready_to_start_meditation': '准备好开始今天的冥想之旅吗？',
      'recent_sessions': '最近播放',
      // Player
      'player_initialization_failed': '初始化播放器失败: {error}',
      'player_now_playing': '播放中',
      'player_no_material_selected': '未选择素材',
      'player_select_material_message': '请先在媒体库中选择一个音频或视频素材',
      'player_shuffle_enabled': '已开启随机播放',
      'player_shuffle_disabled': '已关闭随机播放',
      'player_repeat_mode': '重复模式：{mode}',
      'player_reload_media_data': '重新加载媒体数据以获取更新后的信息',
      // Categories
      'category_meditation': '冥想',
      'category_mindfulness': '正念',
      'category_bedtime': '睡前',
      'category_sleep': '睡眠',
      'category_focus': '专注',
      'category_study': '学习',
      'category_relax': '放松',
      'category_soothing': '舒缓',
      'category_nature': '自然',
      'category_environment': '环境',
      'category_breathing': '呼吸',
      // Meditation
      'meditation_completed': '冥想完成',
      'meditation_congratulations': '恭喜！您已完成了这次冥想练习。',
      'meditation_practice_duration': '练习时长：{minutes} 分钟',
      // Navigation
      'navigation_view_progress': '查看进度',
      'navigation_go_to_media_library': '前往媒体库',
      // Actions
      'action_complete': '完成',
      'action_edit': '编辑',
      'action_share': '分享',
      'action_download': '下载',
      'action_add_to_playlist': '添加到播放列表',
      'action_report': '举报',
      'action_cancel': '取消',
      'action_create': '创建',
      'action_confirm': '确定',
      'action_save': '保存',
      'action_more_options': '更多选项',
      'action_go_to_settings': '去设置',
      // Favorites
      'favorites_added': '已添加到收藏',
      'favorites_removed': '已取消收藏',
      // Playlist
      'playlist_my_favorites': '我的收藏',
      'playlist_mindfulness_practice': '正念练习',
      'playlist_sleep_album': '睡眠专辑',
      'playlist_create_new': '创建新播放列表',
      'playlist_create_playlist': '创建播放列表',
      'playlist_name_label': '播放列表名称',
      'playlist_name_hint': '请输入播放列表名称',
      'playlist_added_to_playlist': '已添加 "{title}" 到 "{playlist}"',
      'playlist_add_media_message': '将 "{title}" 添加到：',
      // Download
      'download_confirm_message': '是否下载 "{title}" 到本地？',
      'download_warning': '注意：此功能需要网络连接，并且会消耗存储空间。',
      'download_start': '开始下载',
      'download_downloading': '正在下载 "{title}"...',
      'download_completed': '下载完成：{title}',
      // Share
      'share_listening_to': '正在收听：{title}',
      'share_category': '类别：{category}',
      'share_description': '描述：{description}',
      'share_app_signature': '来自 Mindra 冥想应用',
      'share_copied_to_clipboard': '分享内容已复制到剪贴板',
      // Timer
      'timer_settings': '定时设置',
      'timer_minutes_after': '{minutes} 分钟后',
      'timer_set_message': '已设置 {minutes} 分钟定时停止',
      'timer_cancel': '取消定时',
      'timer_cancelled': '已取消定时停止',
      // Sound Effects
      'sound_effects_settings': '音效设置',
      'sound_effects_rain': '雨声',
      'sound_effects_ocean': '海浪',
      'sound_effects_wind_chimes': '风铃',
      'sound_effects_birds': '鸟鸣',
      'sound_effects_loading': '正在加载音效...',
      'sound_effects_background_title': '背景音效',
      'sound_effects_background_description': '轻柔的背景音效，不会干扰主要音频',
      'sound_effects_volume_control': '音量控制',
      'sound_effects_settings_saved': '背景音效设置已保存',
      'sound_effects_builtin_config': '预置音效配置',
      // Repeat Mode
      'repeat_mode_off': '关闭',
      'repeat_mode_all': '全部重复',
      'repeat_mode_one': '单曲重复',
      // Audio Focus
      'audio_focus_manager_description': '音频焦点管理器 - 协调主音频和背景音效的播放',
      // Progress
      'progress_my_progress': '我的进度',
      'progress_settings': '进度设置',
      // Stats
      'stats_consecutive_days': '连续天数',
      'stats_weekly_duration': '本周时长',
      'stats_total_sessions': '总次数',
      'stats_weekly_meditation_duration': '本周冥想时长',
      'stats_days_format': '{days}天',
      'stats_minutes_format': '{minutes}分钟',
      'stats_times_format': '{times}次',
      // Achievements
      'achievements_title': '成就徽章',
      'achievements_first_meditation_title': '冥想新手',
      'achievements_first_meditation_description': '完成第一次冥想',
      'achievements_week_streak_title': '连续一周',
      'achievements_week_streak_description': '连续7天进行冥想',
      'achievements_focus_master_title': '专注大师',
      'achievements_focus_master_description': '完成30分钟以上的冥想',
      'achievements_meditation_expert_title': '冥想达人',
      'achievements_meditation_expert_description': '累计冥想时长达到10小时',
      'achievements_consistency_champion_title': '坚持之王',
      'achievements_consistency_champion_description': '连续30天进行冥想',
      'achievements_variety_seeker_title': '多样体验',
      'achievements_variety_seeker_description': '尝试5种不同类型的冥想',
      // History
      'history_meditation_history': '冥想历史',
      // Weekdays
      'weekdays_monday': '周一',
      'weekdays_tuesday': '周二',
      'weekdays_wednesday': '周三',
      'weekdays_thursday': '周四',
      'weekdays_friday': '周五',
      'weekdays_saturday': '周六',
      'weekdays_sunday': '周日',
      // Calendar
      'calendar_sunday': '日',
      'calendar_monday': '一',
      'calendar_tuesday': '二',
      'calendar_wednesday': '三',
      'calendar_thursday': '四',
      'calendar_friday': '五',
      'calendar_saturday': '六',
      // Goals
      'goals_set_goals': '设置目标',
      'goals_adjust_daily_goal': '调整每日冥想目标',
      'goals_settings_title': '目标设置',
      'goals_daily_goal': '每日目标',
      'goals_weekly_goal': '每周目标',
      'goals_default_daily': '20分钟',
      'goals_default_weekly': '7次',
      'goals_select_label': '选择{label}',
      'goals_invalid_format': '目标设置格式不正确',
      'goals_settings_saved': '目标设置已保存',
      'goals_save_failed': '保存失败: {error}',
      // Reminders
      'reminders_settings': '提醒设置',
      'reminders_set_reminder_time': '设置冥想提醒时间',
      'reminders_settings_title': '提醒设置',
      'reminders_time': '提醒时间',
      'reminders_date': '提醒日期',
      'reminders_method': '提醒方式',
      'reminders_enable': '开启提醒',
      'reminders_enable_description': '每日定时提醒您进行冥想',
      'reminders_time_label': '提醒时间',
      'reminders_select_time': '选择时间',
      'reminders_select_dates': '选择提醒日期',
      'reminders_method_label': '提醒方式',
      'reminders_notification': '通知栏提醒',
      'reminders_notification_description': '在通知栏显示提醒消息',
      'reminders_sound': '声音提醒',
      'reminders_sound_description': '播放提醒声音',
      'reminders_vibration': '振动提醒',
      'reminders_vibration_description': '设备振动提醒',
      'reminders_settings_saved': '提醒设置已保存',
      'reminders_disabled': '提醒已关闭',
      'reminders_save_failed': '保存失败: {error}',
      // Permissions
      'permissions_title': '需要权限',
      'permissions_description': '为了发送冥想提醒，需要开启以下权限：\n\n• 通知权限 - 显示提醒消息\n• 精确闹钟权限 - 准时发送提醒\n\n请在系统设置中手动开启这些权限。',
      // Session Types
      'session_types_meditation': '冥想',
      'session_types_breathing': '呼吸',
      'session_types_sleep': '睡眠',
      'session_types_focus': '专注',
      'session_types_relaxation': '放松',
      // Session Categories
      'session_categories_breathing_practice': '呼吸练习',
      'session_categories_sleep_guidance': '睡眠引导',
      'session_categories_focus_training': '专注训练',
      'session_categories_relaxation_meditation': '放松冥想',
      // Layout
      'layout_title_center_placeholder': '占位符，保持标题居中',
      'layout_reduce_spacing': '减小间距',
      // Daily Goal
      'daily_goal_title': '今日目标',
      'daily_goal_meditation_suffix': '冥想',
      'daily_goal_default': '20分钟冥想',
      // Dialog
      'dialog_add_media_title': '添加冥想素材',
      'dialog_edit_media_title': '编辑媒体信息',
      'dialog_add_method': '添加方式',
      'dialog_local_import': '本地导入',
      'dialog_network_link': '网络链接',
      'dialog_select_file': '选择文件',
      'dialog_file_selected': '已选择文件',
      'dialog_media_link': '媒体链接',
      'dialog_media_link_hint': '请输入音频或视频的网络链接',
      'dialog_title': '标题',
      'dialog_title_hint': '请输入素材标题',
      'dialog_duration': '时长',
      'dialog_duration_hint': '请输入时长（秒）',
      'dialog_duration_loading': '正在获取时长...',
      'dialog_category': '分类',
      'dialog_description': '描述',
      'dialog_description_hint': '请输入描述',
      'dialog_thumbnail': '封面图片',
      'dialog_thumbnail_hint': '请输入封面图片链接（可选）',
      'dialog_update': '更新',
      'dialog_save': '保存',
      'dialog_file_selected_success': '已选择文件: {fileName}',
      'dialog_file_selection_failed': '文件选择失败: {error}',
      'dialog_title_required': '请输入标题',
      'dialog_file_required': '请选择文件',
      'dialog_url_required': '请输入媒体链接',
      'dialog_duration_invalid': '请输入有效的时长（秒）',
      'dialog_material_added': '素材添加成功',
      'dialog_media_updated': '媒体信息更新成功',
    },
  };

  static Map<String, String>? _localizedStrings;

  static Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations._internal(locale);
    _localizedStrings = _localizedValues[locale.languageCode];
    return localizations;
  }

  AppLocalizations._internal(this.locale);

  final Locale locale;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String getString(String key) {
    return _localizedStrings?[key] ?? key;
  }

  // Convenience getters
  String get personalCenter => getString('personal_center');
  String get meditator => getString('meditator');
  String get personalizationSettings => getString('personalization_settings');
  String get themeSettings => getString('theme_settings');
  String get languageSettings => getString('language_settings');
  String get notificationSettings => getString('notification_settings');
  String get cardSpacing => getString('card_spacing');
  String get cardPadding => getString('card_padding');
  String get appSettings => getString('app_settings');
  String get privacySettings => getString('privacy_settings');
  String get storageManagement => getString('storage_management');
  String get about => getString('about');
  String get aboutApp => getString('about_app');
  String get selectTheme => getString('select_theme');
  String get selectLanguage => getString('select_language');
  String get simplifiedChinese => getString('simplified_chinese');
  String get english => getString('english');
  String get notificationSettingsTitle =>
      getString('notification_settings_title');
  String get pushNotifications => getString('push_notifications');
  String get pushNotificationsDesc => getString('push_notifications_desc');
  String get dailyReminder => getString('daily_reminder');
  String get dailyReminderDesc => getString('daily_reminder_desc');
  String get sessionReminder => getString('session_reminder');
  String get sessionReminderDesc => getString('session_reminder_desc');
  String get cancel => getString('cancel');
  String get confirm => getString('confirm');
  String get notificationSettingsSaved =>
      getString('notification_settings_saved');
  String get adjustCardSpacing => getString('adjust_card_spacing');
  String get compact8px => getString('compact_8px');
  String get loose32px => getString('loose_32px');
  String get adjustCardPadding => getString('adjust_card_padding');
  String get compact12px => getString('compact_12px');
  String get comingSoon => getString('coming_soon');
  String get comingSoonDesc => getString('coming_soon_desc');
  String get gotIt => getString('got_it');
  String get home => getString('home');
  String get mediaLibrary => getString('media_library');
  String get play => getString('play');
  String get progress => getString('progress');
  String get profile => getString('profile');
  String get pageNotFound => getString('page_not_found');
  String get pageNotFoundDesc => getString('page_not_found_desc');
  String get backToHome => getString('back_to_home');
  String get goodMorning => getString('good_morning');
  String get goodAfternoon => getString('good_afternoon');
  String get goodEvening => getString('good_evening');
  String get readyToStartMeditation => getString('ready_to_start_meditation');
  String get recentSessions => getString('recent_sessions');

  // Player getters
  String get playerNowPlaying => getString('player_now_playing');
  String get playerNoMaterialSelected => getString('player_no_material_selected');
  String get playerSelectMaterialMessage => getString('player_select_material_message');
  String get playerShuffleEnabled => getString('player_shuffle_enabled');
  String get playerShuffleDisabled => getString('player_shuffle_disabled');
  String get playerReloadMediaData => getString('player_reload_media_data');

  // Category getters
  String get categoryMeditation => getString('category_meditation');
  String get categoryMindfulness => getString('category_mindfulness');
  String get categoryBedtime => getString('category_bedtime');
  String get categorySleep => getString('category_sleep');
  String get categoryFocus => getString('category_focus');
  String get categoryStudy => getString('category_study');
  String get categoryRelax => getString('category_relax');
  String get categorySoothing => getString('category_soothing');
  String get categoryNature => getString('category_nature');
  String get categoryEnvironment => getString('category_environment');
  String get categoryBreathing => getString('category_breathing');

  // Meditation getters
  String get meditationCompleted => getString('meditation_completed');
  String get meditationCongratulations => getString('meditation_congratulations');

  // Navigation getters
  String get navigationViewProgress => getString('navigation_view_progress');
  String get navigationGoToMediaLibrary => getString('navigation_go_to_media_library');

  // Action getters
  String get actionComplete => getString('action_complete');
  String get actionEdit => getString('action_edit');
  String get actionShare => getString('action_share');
  String get actionDownload => getString('action_download');
  String get actionAddToPlaylist => getString('action_add_to_playlist');
  String get actionReport => getString('action_report');
  String get actionCancel => getString('action_cancel');
  String get actionCreate => getString('action_create');
  String get actionConfirm => getString('action_confirm');
  String get actionSave => getString('action_save');
  String get actionMoreOptions => getString('action_more_options');
  String get actionGoToSettings => getString('action_go_to_settings');

  // Favorites getters
  String get favoritesAdded => getString('favorites_added');
  String get favoritesRemoved => getString('favorites_removed');

  // Playlist getters
  String get playlistMyFavorites => getString('playlist_my_favorites');
  String get playlistMindfulnessPractice => getString('playlist_mindfulness_practice');
  String get playlistSleepAlbum => getString('playlist_sleep_album');
  String get playlistCreateNew => getString('playlist_create_new');
  String get playlistCreatePlaylist => getString('playlist_create_playlist');
  String get playlistNameLabel => getString('playlist_name_label');
  String get playlistNameHint => getString('playlist_name_hint');

  // Download getters
  String get downloadWarning => getString('download_warning');
  String get downloadStart => getString('download_start');

  // Share getters
  String get shareAppSignature => getString('share_app_signature');
  String get shareCopiedToClipboard => getString('share_copied_to_clipboard');

  // Timer getters
  String get timerSettings => getString('timer_settings');
  String get timerCancel => getString('timer_cancel');
  String get timerCancelled => getString('timer_cancelled');

  // Sound Effects getters
  String get soundEffectsSettings => getString('sound_effects_settings');
  String get soundEffectsRain => getString('sound_effects_rain');
  String get soundEffectsOcean => getString('sound_effects_ocean');
  String get soundEffectsWindChimes => getString('sound_effects_wind_chimes');
  String get soundEffectsBirds => getString('sound_effects_birds');
  String get soundEffectsLoading => getString('sound_effects_loading');
  String get soundEffectsBackgroundTitle => getString('sound_effects_background_title');
  String get soundEffectsBackgroundDescription => getString('sound_effects_background_description');
  String get soundEffectsVolumeControl => getString('sound_effects_volume_control');
  String get soundEffectsSettingsSaved => getString('sound_effects_settings_saved');

  // Repeat Mode getters
  String get repeatModeOff => getString('repeat_mode_off');
  String get repeatModeAll => getString('repeat_mode_all');
  String get repeatModeOne => getString('repeat_mode_one');

  // Progress getters
  String get progressMyProgress => getString('progress_my_progress');
  String get progressSettings => getString('progress_settings');

  // Stats getters
  String get statsConsecutiveDays => getString('stats_consecutive_days');
  String get statsWeeklyDuration => getString('stats_weekly_duration');
  String get statsTotalSessions => getString('stats_total_sessions');
  String get statsWeeklyMeditationDuration => getString('stats_weekly_meditation_duration');

  // Achievements getters
  String get achievementsTitle => getString('achievements_title');
  String get achievementsFirstMeditationTitle => getString('achievements_first_meditation_title');
  String get achievementsFirstMeditationDescription => getString('achievements_first_meditation_description');
  String get achievementsWeekStreakTitle => getString('achievements_week_streak_title');
  String get achievementsWeekStreakDescription => getString('achievements_week_streak_description');
  String get achievementsFocusMasterTitle => getString('achievements_focus_master_title');
  String get achievementsFocusMasterDescription => getString('achievements_focus_master_description');
  String get achievementsMeditationExpertTitle => getString('achievements_meditation_expert_title');
  String get achievementsMeditationExpertDescription => getString('achievements_meditation_expert_description');
  String get achievementsConsistencyChampionTitle => getString('achievements_consistency_champion_title');
  String get achievementsConsistencyChampionDescription => getString('achievements_consistency_champion_description');
  String get achievementsVarietySeekerTitle => getString('achievements_variety_seeker_title');
  String get achievementsVarietySeekerDescription => getString('achievements_variety_seeker_description');

  // History getters
  String get historyMeditationHistory => getString('history_meditation_history');

  // Weekdays getters
  String get weekdaysMonday => getString('weekdays_monday');
  String get weekdaysTuesday => getString('weekdays_tuesday');
  String get weekdaysWednesday => getString('weekdays_wednesday');
  String get weekdaysThursday => getString('weekdays_thursday');
  String get weekdaysFriday => getString('weekdays_friday');
  String get weekdaysSaturday => getString('weekdays_saturday');
  String get weekdaysSunday => getString('weekdays_sunday');

  // Calendar getters
  String get calendarSunday => getString('calendar_sunday');
  String get calendarMonday => getString('calendar_monday');
  String get calendarTuesday => getString('calendar_tuesday');
  String get calendarWednesday => getString('calendar_wednesday');
  String get calendarThursday => getString('calendar_thursday');
  String get calendarFriday => getString('calendar_friday');
  String get calendarSaturday => getString('calendar_saturday');

  // Goals getters
  String get goalsSetGoals => getString('goals_set_goals');
  String get goalsAdjustDailyGoal => getString('goals_adjust_daily_goal');
  String get goalsSettingsTitle => getString('goals_settings_title');
  String get goalsDailyGoal => getString('goals_daily_goal');
  String get goalsWeeklyGoal => getString('goals_weekly_goal');
  String get goalsDefaultDaily => getString('goals_default_daily');
  String get goalsDefaultWeekly => getString('goals_default_weekly');
  String get goalsInvalidFormat => getString('goals_invalid_format');
  String get goalsSettingsSaved => getString('goals_settings_saved');

  // Reminders getters
  String get remindersSettings => getString('reminders_settings');
  String get remindersSetReminderTime => getString('reminders_set_reminder_time');
  String get remindersSettingsTitle => getString('reminders_settings_title');
  String get remindersTime => getString('reminders_time');
  String get remindersDate => getString('reminders_date');
  String get remindersMethod => getString('reminders_method');
  String get remindersEnable => getString('reminders_enable');
  String get remindersEnableDescription => getString('reminders_enable_description');
  String get remindersTimeLabel => getString('reminders_time_label');
  String get remindersSelectTime => getString('reminders_select_time');
  String get remindersSelectDates => getString('reminders_select_dates');
  String get remindersMethodLabel => getString('reminders_method_label');
  String get remindersNotification => getString('reminders_notification');
  String get remindersNotificationDescription => getString('reminders_notification_description');
  String get remindersSound => getString('reminders_sound');
  String get remindersSoundDescription => getString('reminders_sound_description');
  String get remindersVibration => getString('reminders_vibration');
  String get remindersVibrationDescription => getString('reminders_vibration_description');
  String get remindersSettingsSaved => getString('reminders_settings_saved');
  String get remindersDisabled => getString('reminders_disabled');

  // Permissions getters
  String get permissionsTitle => getString('permissions_title');
  String get permissionsDescription => getString('permissions_description');

  // Session Types getters
  String get sessionTypesMeditation => getString('session_types_meditation');
  String get sessionTypesBreathing => getString('session_types_breathing');
  String get sessionTypesSleep => getString('session_types_sleep');
  String get sessionTypesFocus => getString('session_types_focus');
  String get sessionTypesRelaxation => getString('session_types_relaxation');

  // Daily Goal getters
  String get dailyGoalTitle => getString('daily_goal_title');
  String get dailyGoalMeditationSuffix => getString('daily_goal_meditation_suffix');
  String get dailyGoalDefault => getString('daily_goal_default');

  // Dialog getters
  String get dialogAddMediaTitle => getString('dialog_add_media_title');
  String get dialogEditMediaTitle => getString('dialog_edit_media_title');
  String get dialogAddMethod => getString('dialog_add_method');
  String get dialogLocalImport => getString('dialog_local_import');
  String get dialogNetworkLink => getString('dialog_network_link');
  String get dialogSelectFile => getString('dialog_select_file');
  String get dialogFileSelected => getString('dialog_file_selected');
  String get dialogMediaLink => getString('dialog_media_link');
  String get dialogMediaLinkHint => getString('dialog_media_link_hint');
  String get dialogTitle => getString('dialog_title');
  String get dialogTitleHint => getString('dialog_title_hint');
  String get dialogDuration => getString('dialog_duration');
  String get dialogDurationHint => getString('dialog_duration_hint');
  String get dialogDurationLoading => getString('dialog_duration_loading');
  String get dialogCategory => getString('dialog_category');
  String get dialogDescription => getString('dialog_description');
  String get dialogDescriptionHint => getString('dialog_description_hint');
  String get dialogThumbnail => getString('dialog_thumbnail');
  String get dialogThumbnailHint => getString('dialog_thumbnail_hint');
  String get dialogUpdate => getString('dialog_update');
  String get dialogSave => getString('dialog_save');
  String get dialogTitleRequired => getString('dialog_title_required');
  String get dialogFileRequired => getString('dialog_file_required');
  String get dialogUrlRequired => getString('dialog_url_required');
  String get dialogDurationInvalid => getString('dialog_duration_invalid');
  String get dialogMaterialAdded => getString('dialog_material_added');
  String get dialogMediaUpdated => getString('dialog_media_updated');

  String meditatedTimes(int count) {
    final template = getString('meditated_times');
    return template.replaceAll('{count}', count.toString());
  }

  // Player methods with parameters
  String playerInitializationFailed(String error) {
    final template = getString('player_initialization_failed');
    return template.replaceAll('{error}', error);
  }

  String playerRepeatMode(String mode) {
    final template = getString('player_repeat_mode');
    return template.replaceAll('{mode}', mode);
  }

  String meditationPracticeDuration(int minutes) {
    final template = getString('meditation_practice_duration');
    return template.replaceAll('{minutes}', minutes.toString());
  }

  String playlistAddedToPlaylist(String title, String playlist) {
    final template = getString('playlist_added_to_playlist');
    return template.replaceAll('{title}', title).replaceAll('{playlist}', playlist);
  }

  String playlistAddMediaMessage(String title) {
    final template = getString('playlist_add_media_message');
    return template.replaceAll('{title}', title);
  }

  String downloadConfirmMessage(String title) {
    final template = getString('download_confirm_message');
    return template.replaceAll('{title}', title);
  }

  String downloadDownloading(String title) {
    final template = getString('download_downloading');
    return template.replaceAll('{title}', title);
  }

  String downloadCompleted(String title) {
    final template = getString('download_completed');
    return template.replaceAll('{title}', title);
  }

  String shareListeningTo(String title) {
    final template = getString('share_listening_to');
    return template.replaceAll('{title}', title);
  }

  String shareCategory(String category) {
    final template = getString('share_category');
    return template.replaceAll('{category}', category);
  }

  String shareDescription(String description) {
    final template = getString('share_description');
    return template.replaceAll('{description}', description);
  }

  String timerMinutesAfter(int minutes) {
    final template = getString('timer_minutes_after');
    return template.replaceAll('{minutes}', minutes.toString());
  }

  String timerSetMessage(int minutes) {
    final template = getString('timer_set_message');
    return template.replaceAll('{minutes}', minutes.toString());
  }

  String statsDaysFormat(int days) {
    final template = getString('stats_days_format');
    return template.replaceAll('{days}', days.toString());
  }

  String statsMinutesFormat(int minutes) {
    final template = getString('stats_minutes_format');
    return template.replaceAll('{minutes}', minutes.toString());
  }

  String statsTimesFormat(int times) {
    final template = getString('stats_times_format');
    return template.replaceAll('{times}', times.toString());
  }

  String goalsSelectLabel(String label) {
    final template = getString('goals_select_label');
    return template.replaceAll('{label}', label);
  }

  String goalsSaveFailed(String error) {
    final template = getString('goals_save_failed');
    return template.replaceAll('{error}', error);
  }

  String remindersSaveFailed(String error) {
    final template = getString('reminders_save_failed');
    return template.replaceAll('{error}', error);
  }

  String currentSpacing(int value) {
    final template = getString('current_spacing');
    return template.replaceAll('{value}', value.toString());
  }

  String cardSpacingSet(int value) {
    final template = getString('card_spacing_set');
    return template.replaceAll('{value}', value.toString());
  }

  String currentPadding(int value) {
    final template = getString('current_padding');
    return template.replaceAll('{value}', value.toString());
  }

  String cardPaddingSet(int value) {
    final template = getString('card_padding_set');
    return template.replaceAll('{value}', value.toString());
  }

  String dialogFileSelectedSuccess(String fileName) {
    final template = getString('dialog_file_selected_success');
    return template.replaceAll('{fileName}', fileName);
  }

  String dialogFileSelectionFailed(String error) {
    final template = getString('dialog_file_selection_failed');
    return template.replaceAll('{error}', error);
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations._localizedValues.containsKey(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return await AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}
