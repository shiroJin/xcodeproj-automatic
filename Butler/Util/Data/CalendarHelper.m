//
//  CalendarHelper.m
//  HappySports
//
//  Created by jianxing on 15/11/4.
//  Copyright © 2015年 jianxing. All rights reserved.
//

#import "CalendarHelper.h"

@implementation CalendarHelper

NSString *SCCompareRefreshDate(NSDate *lastDate) {
    NSDate *nowDate = [NSDate date];
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSUInteger unitFlags = NSCalendarUnitMinute | NSCalendarUnitHour | NSCalendarUnitDay | NSCalendarUnitWeekOfMonth | NSCalendarUnitMonth | NSCalendarUnitYear;
    NSDateComponents *components = [calendar components:unitFlags fromDate:lastDate toDate:nowDate options:0];
    if (components.day > 1) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"MM-dd HH:mm:ss"];
        return [NSString stringWithFormat:@"最后刷新：%@", [dateFormatter stringFromDate:lastDate]];
    }
    if (components.hour >= 1) {
        return [NSString stringWithFormat:@"最后刷新：%ld小时前", (long)components.hour];
    }
    if (components.minute >= 1) {
        return [NSString stringWithFormat:@"最后刷新：%ld分钟前", (long)components.minute];
    }
    return @"最后刷新：刚刚";
}

+ (NSCalendar *)calendar{
    NSCalendar *cal = [NSCalendar currentCalendar];
    [cal setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [cal setFirstWeekday:2];// 设定每周的第一天从星期一开始
    return cal;
}

+ (NSDate *)getNowDateForDate:(NSDate *)date{
    NSTimeZone *zone = [NSTimeZone systemTimeZone]; // 获得系统的时区
    NSTimeInterval time = [zone secondsFromGMTForDate:date];// 以秒为单位返回当前时间与系统格林尼治时间的差
    NSDate *dateNow = [date dateByAddingTimeInterval:time];// 然后把差的时间加上,就是当前系统准确的时间
    return dateNow;
}

+ (NSInteger)getMonthDayWithDate:(NSDate *)date{
    NSRange days = [[self calendar] rangeOfUnit:NSCalendarUnitDay
                           inUnit:NSCalendarUnitMonth
                          forDate:date];
    NSLog(@"当前这个月有%ld天",(unsigned long)days.length);
    return days.length;
}

+ (NSInteger)getMonthWeekWithDate:(NSDate *)date{
    NSRange weeks = [[self calendar] rangeOfUnit:NSCalendarUnitWeekOfMonth
                                         inUnit:NSCalendarUnitMonth
                                        forDate:date];
    NSLog(@"当前这个月有%ld周",(unsigned long)weeks.length);
    return weeks.length;
}

+ (NSDate *)getMonthFirstDayForDate:(NSDate *)date{
    NSDateComponents *comps = [[self calendar] components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:date];
    comps.day = 1;
    NSDate *firstDay = [[self calendar] dateFromComponents:comps];
    NSLog(@"当前这个月第一天是%@",firstDay);
    return firstDay;
}

+ (NSDate *)getYearForDate:(NSDate *)date difference:(int)num{
    NSDateComponents *adcomps = [[NSDateComponents alloc] init];
    [adcomps setYear:num];
    [adcomps setMonth:0];
    [adcomps setDay:0];
    NSDate *newdate = [[self calendar] dateByAddingComponents:adcomps toDate:date options:0];
    return newdate;
}

+ (NSDate *)getMonthForDate:(NSDate *)date difference:(int)num{
    NSDateComponents *adcomps = [[NSDateComponents alloc] init];
    [adcomps setYear:0];
    [adcomps setMonth:num];
    [adcomps setDay:0];
    NSDate *newdate = [[self calendar] dateByAddingComponents:adcomps toDate:date options:0];
    return newdate;
}

+ (NSDate *)getDayForDate:(NSDate *)date difference:(int)num{
    NSDateComponents *adcomps = [[NSDateComponents alloc] init];
    [adcomps setYear:0];
    [adcomps setMonth:0];
    [adcomps setDay:num];
    NSDate *newdate = [[self calendar] dateByAddingComponents:adcomps toDate:date options:0];
    return newdate;
}

+ (NSArray *)getMonthDaysForDate:(NSDate *)date{
    NSMutableArray *array = [NSMutableArray new];
    NSInteger days = [self getMonthDayWithDate:date];
    NSDate *firstDate = [self getMonthFirstDayForDate:date];
    for (int i = 0; i<days; i++) {
        NSDate *date = [firstDate dateByAddingTimeInterval:60*60*24*i];
        [array addObject:date];
    }
    return array;
}

//根据时间获取所有该时间后到当前月的所有月份
+ (NSArray *)getMonthsFromDate:(NSString *)dateStr{
    NSMutableArray *array = [NSMutableArray new];
     NSDate *date = [CalendarHelper getDateFromString:dateStr withFormatter:@"yyyy-MM"];
     NSInteger year = [[CalendarHelper convertStringFromDate:date type:@"yyyy"]integerValue];
    
     NSDate *curDate = [NSDate date];
     NSInteger curYear = [[CalendarHelper convertStringFromDate:curDate type:@"yyyy"]integerValue];
     NSInteger curMonth = [[CalendarHelper convertStringFromDate:curDate type:@"MM"]integerValue];
    
    for (NSInteger i = curMonth; i > 0; i--) {
       NSString *yearMonthStr = [NSString stringWithFormat:@"%zd-%02zd",curYear,i];
        [array addObject:yearMonthStr];
    }
    --curYear;
    while (year <= curYear) {
        for (int i = 12; i > 0; i--) {
            NSString *yearMonthStr = [NSString stringWithFormat:@"%zd-%02d",curYear,i];
            [array addObject:yearMonthStr];
        }
        --curYear;
    }
    
    
    return array;
}

+ (NSString *)getWeekNumberForDate:(NSDate *)date{
    NSArray *weekdays = [NSArray arrayWithObjects:@"周日", @"周一", @"周二", @"周三", @"周四", @"周五", @"周六", nil];
    NSCalendarUnit calendarUnit = NSCalendarUnitWeekday;
    NSDateComponents *theComponents = [[self calendar] components:calendarUnit fromDate:date];
    return [weekdays objectAtIndex:theComponents.weekday-1];
}

+ (NSString *)getDayNumberForDate:(NSDate *)date{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"dd"];
    NSString *dateStr = [dateFormatter stringFromDate:date];
    return dateStr;
}

+ (NSDate *)resetZeroDate:(NSDate *)date{
    NSDateComponents *currentDateComponents = [[self calendar] components:NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:date];
    NSDateComponents *currentDateToMidnight = [[NSDateComponents alloc] init];
    [currentDateToMidnight setHour:-[currentDateComponents hour]];
    [currentDateToMidnight setMinute:-[currentDateComponents minute]];
    [currentDateToMidnight setSecond:-[currentDateComponents second]];
    NSDate *midnight = [[self calendar] dateByAddingComponents:currentDateToMidnight toDate:date options:0];
    return midnight;
}

/*
 * 根据时间计算里今天结束还有多少秒
 */
+ (NSTimeInterval)getDifferenceDayEndDate:(NSDate *)date{
    NSDate *nextDate = [self resetZeroDate:[self getDayForDate:date difference:1]];
    NSTimeInterval time = [nextDate timeIntervalSinceDate:date];
    return time;
}

+ (BOOL)isDayForNightForDate:(NSDate *)date{
    NSDateComponents *components = [[self calendar] components:NSCalendarUnitHour fromDate:[self getNowDateForDate:date]];
    if(components.hour >= 6 && components.hour<18) {
        return YES;
    }else{
        return NO;
    }
}

+ (NSString *)convertStringFromDate:(NSDate *)date type:(NSString *)type{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:type];
    return [dateFormatter stringFromDate:date];
}

+ (NSDate *)getDateFromString:(NSString *)dateString withFormatter:(NSString *)formatterString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
    
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:formatterString]; //@"yyyy'-'MM'-'dd' 'HH':'mm"
    [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
    
    return [dateFormatter dateFromString:dateString];
}

+ (int)compareTime:(NSString *)timeA withAnotherTime:(NSString *)timeB formatter:(NSString *)formatterStr
{
    NSDate *timeADate = [self getDateFromString:timeA withFormatter:formatterStr];
    NSDate *timeBDate = [self getDateFromString:timeB withFormatter:formatterStr];
    NSComparisonResult result = [timeADate compare:timeBDate];
    
    if (result == NSOrderedDescending) {
        //NSLog(@"timeADate  is in the future");
        return 1;
    }
    else if (result == NSOrderedAscending){
        //NSLog(@"timeADate is in the past");
        return -1;
    }
    
    return 0;
}

@end
