//
//  ImageUtils.h
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>

@interface ImageUtils : NSObject

// Вырезана большая часть статических методов для работы с изображениями разного рода
// ...

// Конвертирует "голое" изображение из формата YUV420 в формат RGB24
+(void) RawImage_YUV420toABGR: (const unsigned char*)yuv420Data abgrData:(unsigned char*)abgrData width:(size_t)width height:(size_t)height;

@end
