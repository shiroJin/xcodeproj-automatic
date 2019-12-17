//
//  CalendarHelper.h
//  HappySports
//
//  Created by jianxing on 15/11/4.
//  Copyright © 2015年 jianxing. All rights reserved.
//

#import <Foundation/Foundation.h>

// 计算工作台首页下拉刷新的时间文案函数
extern NSString *SCCompareRefreshDate(NSDate *lastDate);

@interface CalendarHelper : NSObject

+ (NSCalendar *)calendar;

/*
 * 根据时间获取对应当前系统的时间
 */
+ (NSDate *)getNowDateForDate:(NSDate *)date;

/*
 * 根据时间获取这个月有多少天
 */
+ (NSInteger)getMonthDayWithDate:(NSDate *)date;

/*
 * 根据时间获取这个月有几周
 */
+ (NSInteger)getMonthWeekWithDate:(NSDate *)date;

/*
 * 根据时间获取这个月的第一天
 */
+ (NSDate *)getMonthFirstDayForDate:(NSDate *)date;

/*
 * 根据时间获取前后几年的时间
 */
+ (NSDate *)getYearForDate:(NSDate *)date difference:(int)num;

/*
 * 根据时间获取前后几月的时间
 */
+ (NSDate *)getMonthForDate:(NSDate *)date difference:(int)num;

/*
 * 根据时间获取前后几天的时间
 */
+ (NSDate *)getDayForDate:(NSDate *)date difference:(int)num;

/*
 * 根据时间获取这个月所有天
 */
+ (NSArray *)getMonthDaysForDate:(NSDate *)date;

/*
 * 根据时间显示周几
 */
+ (NSString *)getWeekNumberForDate:(NSDate *)date;

/*
 * 根据时间显示几号
 */
+ (NSString *)getDayNumberForDate:(NSDate *)date;

/*
 * 重置时间为当天0点
 */
+ (NSDate *)resetZeroDate:(NSDate *)date;

/*
 * 根据时间计算里今天结束还有多少秒
 */
+ (NSTimeInterval)getDifferenceDayEndDate:(NSDate *)date;

/*
 * 判断白天还是晚上（6:00~18:00算白天）
 */
+ (BOOL)isDayForNightForDate:(NSDate *)date;

/*
 *根据时间获取所有该时间后到当前月的所有月份
 */
+ (NSArray *)getMonthsFromDate:(NSString *)dateStr;

/**
 *  @author Regan, 15-11-11 20:11:13
 *
 *  @brief  时间转换成字符串
 *
 *  @param date date
 *  @param type 时间格式
 *
 *  @return 时间字符串
 */
+ (NSString *)convertStringFromDate:(NSDate *)date type:(NSString *)type;

/// 把时间字符串转换成NSDate对象
+ (NSDate *)getDateFromString:(NSString *)dateString withFormatter:(NSString *)formatterString;

/// 返回两个时间比较值，1为timeA > timeB,0为相等，-1位timeA < timeB
+ (int)compareTime:(NSString *)timeA withAnotherTime:(NSString *)timeB formatter:(NSString *)formatterStr;
@end
