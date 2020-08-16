//
//  CoreViewController.h
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AudioDeviceManager.h"
#import "VideoCaptureManager.h"
#import "ImageUtils.h"

/// Реализует контроллер основного представления приложения
/// -------------------------------------------------------
@interface CoreViewController : UIViewController <VideoCaptureManagerDelegate>

// Инициализация пользовательского интерфейса
- (void)initializeUI;

@end
