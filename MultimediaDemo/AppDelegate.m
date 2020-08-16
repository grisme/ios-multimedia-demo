//
//  AppDelegate.m
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import "AppDelegate.h"

/// Реализует делегат приложения
@interface AppDelegate ()
@end

@implementation AppDelegate

// Обработка события - приложение успешно завершило запуск
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

// Обработка события - приложение будет выгружено
- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
