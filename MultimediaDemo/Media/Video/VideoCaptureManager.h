//
//  VideoCaptureManager.h
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/// Реализует протокол делегирования от менеджера захвата видео с камеры
/// -----------------------------------------------------
@protocol VideoCaptureManagerDelegate <NSObject>
// Захвачен видео-кадр с камеры в формате YUV420 (крайне популярный формат для дальнейшего сжатия видео, большинство кодеков ждут на вход YUV420)
// yuvData - указатель на буфер данных в котором расположен несжатый кадр
// yuvDataSize - размер буфера yuvData в байтах
// yuv420Width - ширина захваченого кадра
// yuv420Height - высота захваченого кадра
@optional -(void)videoCaptureManager:(id)captureManager yuv420Received:(const unsigned char*)yuvData yuv420BufferSize:(size_t)yuvDataSize yuv420Width:(size_t)width yuv420Height:(size_t)height;
@end

/// Реализует менеджер захвата видео с камеры
/// Является делегатом для captureDeviceOutput
/// -----------------------------------------------------
@interface VideoCaptureManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>

// Коллекция делегатов менеджера захвата с камеры
@property NSMutableArray <NSObject<VideoCaptureManagerDelegate>*> *delegates;
@property NSLock *delegatesLock;
- (void)delegateAppend:(NSObject<VideoCaptureManagerDelegate>*)delegate;
- (void)delegateRemove:(NSObject<VideoCaptureManagerDelegate>*)delegate;

// Объекты AVFoundation
@property AVCaptureDevice			*captureDevice;			// устройство захвата видео
@property AVCaptureDeviceInput		*captureDeviceInput;	// объект реализующий входящую связь для AVCaptureSession
@property AVCaptureSession			*captureSession;		// сессия захвата
@property AVCaptureVideoDataOutput	*captureDeviceOutput;	// объект реализующий исходящую связь для AVCaptureSession - производит финальную обработку захваченного видео

// Состояние инициализации
@property	BOOL		isInitialized;

// Инициализатор менеджера видео-захвата
- (id)init;

// Возвращает признак разрешения пользователем использования камеры
+ (BOOL)isCapturingAllowed;

// Возвращает инстанс AVCaptureDevice для front-камеры, или NULL, если такой нету
- (AVCaptureDevice*)getFrontCameraDevice;
// Возвращает инстанс AVCaptureDevice для back-камеры, или NULL, если такой нету
- (AVCaptureDevice*)getBackCameraDevice;

// Инициализация и деинициализация захвата видео с камеры
- (bool)initializeVideoCapture;
- (bool)initializeVideoCaptureWithDevice:(AVCaptureDevice *)device;
- (void)deinitializeVideoCapture;
- (bool)toggleCamera;

@end
