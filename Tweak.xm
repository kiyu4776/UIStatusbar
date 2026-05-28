@import UIKit;
#import <Cephei/HBPreferences.h>
#import <mach/mach.h>
#import <sys/sysctl.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#import <Foundation/Foundation.h>
#import <sys/utsname.h>

static BOOL IsEnable;
static BOOL IsLegacyMode;
static BOOL isLowBatteryLevel;
static BOOL UIStatusBarImageViewHidden;
static NSInteger RAMDisplayType;
static CGFloat FontSize;
static NSString *CustomFormat;
static CGFloat BatteryLevelThreshold = 0.20;
static CGFloat UpdateInterval = 3.0;
static const char kTimerKey[] = "kTimerKey";
static bool LocaleCountry_JP;
static bool LineBreakModeisNone;
static bool symbolhiden = NO;
static NSString *symbolName;

int isHomeButtonDevice(void) { // 多分これ意味ない
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *model = [NSString stringWithCString:systemInfo.machine 
                        encoding:NSUTF8StringEncoding];
    NSArray *homeButtonDevices = @[
        @"iPhone8,1",   // iPhone 6s
        @"iPhone8,2",   // iPhone 6s Plus
        @"iPhone9,1",   // iPhone 7
        @"iPhone9,2",   // iPhone 7 Plus
        @"iPhone9,3",   // iPhone 7
        @"iPhone9,4",   // iPhone 7 Plus
        @"iPhone10,1",  // iPhone 8
        @"iPhone10,2",  // iPhone 8 Plus
        @"iPhone10,4",  // iPhone 8 
        @"iPhone10,5",  // iPhone 8 Plus
        @"iPhone8,4",   // iPhone SE1
        @"iPhone12,8",  // iPhone SE2
        @"iPhone14,6",  // iPhone SE3
    ];
    
    return [homeButtonDevices containsObject:model] ? 1 : 0;
}



@interface _UIStatusBarStringView : UIView
- (NSString *)text;
- (void)setText:(NSString *)text;
- (void)ptr_refresh;
@end

%hook _UIStatusBarStringView
 

- (void)didMoveToWindow {
    %orig;
    NSTimer *oldTimer = objc_getAssociatedObject(self, kTimerKey);
    if (oldTimer) {
        [oldTimer invalidate];
        oldTimer = nil;
    }
    if (IsEnable && self.window) {
        [self ptr_refresh];
        NSTimer *newTimer = [NSTimer scheduledTimerWithTimeInterval:UpdateInterval target:self selector:@selector(ptr_refresh) userInfo:nil repeats:YES];
        objc_setAssociatedObject(self, kTimerKey, newTimer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%new
- (void)ptr_refresh {
    [self setText:[self text]];
}

static NSString* getRAMString() {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
    vm_statistics64_data_t vm_stat;
    if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size) != KERN_SUCCESS) return nil;
    vm_size_t pagesize;
    host_page_size(host_port, &pagesize);
    long total = [[NSProcessInfo processInfo] physicalMemory];
    long used = ((int64_t)vm_stat.active_count + (int64_t)vm_stat.inactive_count + (int64_t)vm_stat.wire_count) * pagesize;
    if (RAMDisplayType == 3) {
        long free_ram = total - used;
        return [NSString stringWithFormat:@"RAM:%.0f%%", ((float)free_ram / total) * 100.0f];
    } else if (RAMDisplayType == 2) {
        long free_ram = total - used;
        return [NSString stringWithFormat:@"RAM:%ldMB", free_ram / (1024 * 1024)];
    } else if (RAMDisplayType == 1) {
        return [NSString stringWithFormat:@"RAM:%ldMB", used / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"RAM:%.0f%%", ((float)used / total) * 100.0f];
    }
}

static float getCPUUsage() {
    static host_cpu_load_info_data_t prev;
    host_cpu_load_info_data_t curr;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&curr, &count) != KERN_SUCCESS) {
        return 0.0f;
    }
    uint32_t *c = curr.cpu_ticks;
    uint32_t *p = prev.cpu_ticks;
    float user_diff = (float)(c[CPU_STATE_USER]   - p[CPU_STATE_USER]);
    float sys_diff  = (float)(c[CPU_STATE_SYSTEM] - p[CPU_STATE_SYSTEM]);
    float nice_diff = (float)(c[CPU_STATE_NICE]   - p[CPU_STATE_NICE]);
    float idle_diff = (float)(c[CPU_STATE_IDLE]   - p[CPU_STATE_IDLE]);
    prev = curr;
    float total_ticks = user_diff + sys_diff + nice_diff + idle_diff;
    if (total_ticks > 0) {
        float idle_percentage = (idle_diff / total_ticks) * 100.0f;
        return 100.0f - idle_percentage;
    }
    return 0.0f;
}

static NSString *getIP() {
    struct ifaddrs *ifa, *ifList;
    if (getifaddrs(&ifList) != 0) return @"-";
    
    for (ifa = ifList; ifa; ifa = ifa->ifa_next) {
        if (!ifa->ifa_addr || ifa->ifa_addr->sa_family != AF_INET) continue;
        if (strcmp(ifa->ifa_name, "en0") == 0) {
            char buf[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr, buf, sizeof(buf));
            freeifaddrs(ifList);
            return @(buf);
        }
    }
    freeifaddrs(ifList);
    return @"-";
}



static NSString* replacePlaceholders(NSString *format) {
    if (!format || [format length] == 0) return @"";

    NSString *escaped = [format stringByReplacingOccurrencesOfString:@"&c" withString:@"'&c'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"&M" withString:@"'&M'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"&p" withString:@"'&p'"];
    escaped = [escaped stringByReplacingOccurrencesOfString:@"\\n" withString:@"'\n'"];

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:escaped];
    if (LocaleCountry_JP) {
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"ja_JP"]];
    } else {
        [formatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"]];
    }

    NSMutableString *result = [[formatter stringFromDate:[NSDate date]] mutableCopy];

    if ([result containsString:@"&c"]) {
        float cpu = getCPUUsage();
        [result replaceOccurrencesOfString:@"&c" withString:[NSString stringWithFormat:@"%.0f%%", cpu] options:0 range:NSMakeRange(0, result.length)];
    }

    if ([result containsString:@"&M"]) {
        NSString *ram = getRAMString();
        [result replaceOccurrencesOfString:@"&M" withString:ram options:0 range:NSMakeRange(0, result.length)];
    }

    if ([result containsString:@"&p"]) {
        NSString *ip = getIP();
        [result replaceOccurrencesOfString:@"&p" withString:ip options:0 range:NSMakeRange(0, result.length)];
    }

    return result;
}

- (void)setText:(NSString *)text {
    if (IsEnable && [text containsString:@":"] && CustomFormat && CustomFormat.length > 0 ) {
        [(id)self setNumberOfLines:-1];
        ((UILabel *)self).lineBreakMode = (NSLineBreakMode)999999;
        [(UILabel *)self setFont:[UIFont systemFontOfSize:FontSize weight:UIFontWeightMedium]];
        NSString *formatted = replacePlaceholders(CustomFormat);
        %orig(formatted);
    } else {
        %orig(text);
    }
}
%end

@interface UIStatusBar_Base : UIView
@end

%hook UIStatusBar_Base

- (void)didMoveToWindow {
    %orig;
    if (IsLegacyMode) {
        [self setValue:@1 forKey:@"mode"];
    }
   
}

%end

@interface _UIBatteryView : UIView
@end

%hook _UIBatteryView

- (void)didMoveToWindow {
    %orig;
    if (isLowBatteryLevel) {
        [self setValue:@(BatteryLevelThreshold) forKey:@"lowBatteryChargePercentThreshold"];
    }
}

%end

@interface _UIStatusBarImageView : UIView
@end

%hook _UIStatusBarImageView

- (void)setImage:(UIImage *)image {
    if (image && [image.description containsString:symbolName] && symbolhiden) {
        %orig(nil);
        return;
    } else {
        %orig(image);
    }
}

%end
%ctor {
    HBPreferences *preferences = [[HBPreferences alloc] initWithIdentifier:@"com.main.kiyu4776.ui.statusbar"];
    {}
    [preferences registerBool:&IsEnable default:NO forKey:@"IsEnable"];

    if (isHomeButtonDevice() == 1) {
        [preferences registerObject:&CustomFormat default:@"E MM/DD &M" forKey:@"CustomFormat"];
    } else {
        [preferences registerObject:&CustomFormat default:@" E hh:mm \n &M" forKey:@"CustomFormat"];
    }
    [preferences registerBool:&IsLegacyMode default:NO forKey:@"IsLegacyMode"];
    [preferences registerFloat:&FontSize default:12.0 forKey:@"FontSize"];
    [preferences registerFloat:&UpdateInterval default:3.0 forKey:@"UpdateInterval"];
    [preferences registerFloat:&BatteryLevelThreshold default:0.20 forKey:@"BatteryLevelThreshold"];
    [preferences registerBool:&isLowBatteryLevel default:NO forKey:@"isLowBatteryLevel"];
    [preferences registerBool:&UIStatusBarImageViewHidden default:NO forKey:@"UIStatusBarImageViewHidden"];
    [preferences registerInteger:&RAMDisplayType default:0 forKey:@"RAMDisplayType"];
    [preferences registerBool:&LocaleCountry_JP default:YES forKey:@"LocaleCountry_JP"];
    [preferences registerBool:&LineBreakModeisNone default:NO forKey:@"LineBreakModeisNone"];
    [preferences registerBool:&symbolhiden default:NO forKey:@"symbolhiden"];
    [preferences registerObject:&symbolName default:@"moon.fill" forKey:@"symbolName"];
}
