import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';

/// 星期几枚举
enum Weekday {
  monday, // 周一
  tuesday, // 周二
  wednesday, // 周三
  thursday, // 周四
  friday, // 周五
  saturday, // 周六
  sunday, // 周日
}

/// 星期几扩展方法
extension WeekdayExtension on Weekday {
  /// 获取本地化显示名称
  String getDisplayName(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (this) {
      case Weekday.monday:
        return localizations.weekdaysMonday;
      case Weekday.tuesday:
        return localizations.weekdaysTuesday;
      case Weekday.wednesday:
        return localizations.weekdaysWednesday;
      case Weekday.thursday:
        return localizations.weekdaysThursday;
      case Weekday.friday:
        return localizations.weekdaysFriday;
      case Weekday.saturday:
        return localizations.weekdaysSaturday;
      case Weekday.sunday:
        return localizations.weekdaysSunday;
    }
  }

  /// 获取本地化显示名称（无需Context，使用指定语言）
  String getDisplayNameWithLocale(AppLocalizations localizations) {
    switch (this) {
      case Weekday.monday:
        return localizations.weekdaysMonday;
      case Weekday.tuesday:
        return localizations.weekdaysTuesday;
      case Weekday.wednesday:
        return localizations.weekdaysWednesday;
      case Weekday.thursday:
        return localizations.weekdaysThursday;
      case Weekday.friday:
        return localizations.weekdaysFriday;
      case Weekday.saturday:
        return localizations.weekdaysSaturday;
      case Weekday.sunday:
        return localizations.weekdaysSunday;
    }
  }

  /// 获取日历显示名称（短格式）
  String getCalendarDisplayName(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    switch (this) {
      case Weekday.monday:
        return localizations.calendarMonday;
      case Weekday.tuesday:
        return localizations.calendarTuesday;
      case Weekday.wednesday:
        return localizations.calendarWednesday;
      case Weekday.thursday:
        return localizations.calendarThursday;
      case Weekday.friday:
        return localizations.calendarFriday;
      case Weekday.saturday:
        return localizations.calendarSaturday;
      case Weekday.sunday:
        return localizations.calendarSunday;
    }
  }

  /// 获取Flutter DateTime的weekday值 (1=Monday, 7=Sunday)
  int get flutterWeekday {
    switch (this) {
      case Weekday.monday:
        return 1;
      case Weekday.tuesday:
        return 2;
      case Weekday.wednesday:
        return 3;
      case Weekday.thursday:
        return 4;
      case Weekday.friday:
        return 5;
      case Weekday.saturday:
        return 6;
      case Weekday.sunday:
        return 7;
    }
  }

  /// 从Flutter DateTime的weekday值创建枚举
  static Weekday fromFlutterWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return Weekday.monday;
      case 2:
        return Weekday.tuesday;
      case 3:
        return Weekday.wednesday;
      case 4:
        return Weekday.thursday;
      case 5:
        return Weekday.friday;
      case 6:
        return Weekday.saturday;
      case 7:
        return Weekday.sunday;
      default:
        return Weekday.monday; // 默认值
    }
  }

  /// 从字符串创建枚举（用于数据库读取）
  static Weekday fromString(String value) {
    switch (value.toLowerCase()) {
      case 'monday':
        return Weekday.monday;
      case 'tuesday':
        return Weekday.tuesday;
      case 'wednesday':
        return Weekday.wednesday;
      case 'thursday':
        return Weekday.thursday;
      case 'friday':
        return Weekday.friday;
      case 'saturday':
        return Weekday.saturday;
      case 'sunday':
        return Weekday.sunday;
      default:
        return Weekday.monday; // 默认值
    }
  }

  /// 从本地化字符串创建枚举（用于兼容旧数据）
  static Weekday fromLocalizedString(String value) {
    // 中文映射
    switch (value) {
      case '周一':
        return Weekday.monday;
      case '周二':
        return Weekday.tuesday;
      case '周三':
        return Weekday.wednesday;
      case '周四':
        return Weekday.thursday;
      case '周五':
        return Weekday.friday;
      case '周六':
        return Weekday.saturday;
      case '周日':
        return Weekday.sunday;
      default:
        // 尝试英文映射
        return fromString(value);
    }
  }

  /// 获取所有星期几列表
  static List<Weekday> get allWeekdays => Weekday.values;

  /// 获取工作日列表
  static List<Weekday> get workdays => [
    Weekday.monday,
    Weekday.tuesday,
    Weekday.wednesday,
    Weekday.thursday,
    Weekday.friday,
  ];

  /// 获取周末列表
  static List<Weekday> get weekends => [Weekday.saturday, Weekday.sunday];
}

/// 星期几列表扩展方法
extension WeekdayListExtension on List<Weekday> {
  /// 转换为Flutter weekday值列表
  List<int> get flutterWeekdays => map((w) => w.flutterWeekday).toList();

  /// 转换为字符串列表（用于存储）
  List<String> get stringValues => map((w) => w.name).toList();

  /// 获取本地化显示名称列表
  List<String> getDisplayNames(BuildContext context) {
    return map((w) => w.getDisplayName(context)).toList();
  }

  /// 获取本地化显示名称列表（无需Context）
  List<String> getDisplayNamesWithLocale(AppLocalizations localizations) {
    return map((w) => w.getDisplayNameWithLocale(localizations)).toList();
  }

  /// 从字符串列表创建枚举列表
  static List<Weekday> fromStringList(List<String> values) {
    return values.map((v) => WeekdayExtension.fromString(v)).toList();
  }

  /// 从本地化字符串列表创建枚举列表
  static List<Weekday> fromLocalizedStringList(List<String> values) {
    return values.map((v) => WeekdayExtension.fromLocalizedString(v)).toList();
  }

  /// 从Flutter weekday值列表创建枚举列表
  static List<Weekday> fromFlutterWeekdayList(List<int> values) {
    return values.map((v) => WeekdayExtension.fromFlutterWeekday(v)).toList();
  }
}
