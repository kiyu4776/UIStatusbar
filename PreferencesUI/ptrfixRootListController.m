#import <Cephei/Cephei.h>
#import <Cephei/HBPreferences.h>
#import <Cephei/HBRespringController.h>
#import <Foundation/Foundation.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <sys/utsname.h>

// 共通クラス
@interface baseListController : PSListController
@end

@implementation baseListController

- (void)Respring {
  [HBRespringController respring];
}
@end

// main Root.plist
@interface ptrfixRootListController : baseListController
@end

@implementation ptrfixRootListController
- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];

  }
  return _specifiers;
}

@end

@interface ptrfixSubOptionsListController : baseListController
@end

// SubOption用
@implementation ptrfixSubOptionsListController
- (NSArray *)specifiers {
  if (!_specifiers) {
    _specifiers = [self loadSpecifiersFromPlistName:@"SubOptions" target:self];
  }
  return _specifiers;
}

@end
