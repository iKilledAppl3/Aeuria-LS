#import "ALSPreferencesSubListController.h"

NSString *kALSPreferencesSubListStateChanged = @"ALSPreferencesSubListStateChanged";

@implementation ALSPreferencesSubListController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kALSPreferencesSubListStateChanged object:self userInfo:@{@"appearing":@(YES)}];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kALSPreferencesSubListStateChanged object:self userInfo:@{@"appearing":@(NO)}];
}

@end