//
//  ImageUtils.mm
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import "ImageUtils.h"
#include "libyuv.h"
#include "YUVImage.h"

@implementation ImageUtils

// Вырезана большая часть статических методов для работы с изображениями разного рода
// ...

// Конвертирует
+(void)RawImage_YUV420toABGR:(const unsigned char *)yuv420Data abgrData:(unsigned char *)abgrData width:(size_t)width height:(size_t)height {
    
    // Используем YUV_frame структуру для удобного разложения линейного буфера YUV420 по компонентам
    YUV_frame frame;
    YUVHelper::YUV_frame_from_buffer(&frame, (unsigned char*)yuv420Data, (const int)width, (const int)height, I420);
    
    // Конвертируем YUV420 в ABGR при помощи библиотеки libyuv
    libyuv::I420ToABGR(frame.Y.buff, frame.Y.lineStride, frame.U.buff, frame.U.lineStride, frame.V.buff, frame.V.lineStride, abgrData, (int)(width * 4), (int)width, (int)height);
}

@end
