//
//  VideoCaptureManager.m
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import "VideoCaptureManager.h"

/// Реализует менеджер захвата видео с камеры
/// -------------------------------------------------
@implementation VideoCaptureManager {
}

// Инициализация менеджера захвата видео
- (id)init {
	self = [super init];
	if (self){
		// Инициализация собственных свойств
		_delegatesLock = [[NSLock alloc] init];
		_delegates = [[NSMutableArray alloc] init];
		_isInitialized	= NO;
        
		// Инициализация объектов AVFoundation
		_captureSession			= nil;
		_captureDevice			= nil;
		_captureDeviceOutput	= nil;
		_captureDeviceInput		= nil;
	}
	return self;
}

// Деструктор
- (void)dealloc {
	[self deinitializeVideoCapture];
}

// Добавляет делегата в коллекцию
- (void)delegateAppend:(NSObject<VideoCaptureManagerDelegate> *)delegate {
	[_delegatesLock lock];
        if (![_delegates containsObject:delegate])
            [_delegates addObject:delegate];
	[_delegatesLock unlock];
}

// Удаляет делегата из коллекции
- (void)delegateRemove:(NSObject<VideoCaptureManagerDelegate> *)delegate {
	[_delegatesLock lock];
        if ([_delegates containsObject:delegate])
            [_delegates removeObject:delegate];
	[_delegatesLock unlock];
}

// Возвращает признак разрешения пользователем использования камеры
+ (BOOL)isCapturingAllowed {
	AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
	return authStatus == AVAuthorizationStatusAuthorized;
}

// Возвращает инстанс AVCaptureDevice для front-камеры, или NULL, если такой нету
- (AVCaptureDevice*)getFrontCameraDevice {
    return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionFront];
}

// Возвращает инстанс AVCaptureDevice для back-камеры, или NULL, если такой нету
- (AVCaptureDevice*)getBackCameraDevice {
	return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
}

// Инициализация и запуск сессии захвата видео с конкретной камеры
- (bool)initializeVideoCaptureWithDevice:(AVCaptureDevice *)device {
	if (!device)
		return false;
		
	// Для возможности переинициализировать камеру одним вызовом	
	if (self.isInitialized)
		[self deinitializeVideoCapture];
	
	// Инициализация AVCaptureSession
	_captureDevice = device;
	_captureSession			= [[AVCaptureSession alloc] init];
	_captureDeviceInput		= [[AVCaptureDeviceInput alloc] initWithDevice:_captureDevice error:NULL];
	_captureDeviceOutput	= [AVCaptureVideoDataOutput new];
	_captureSession.sessionPreset = AVCaptureSessionPreset640x480;
	
	// Конфигурирование выходной связи _captureDeviceOutput
	_captureDeviceOutput.alwaysDiscardsLateVideoFrames	= YES;
	NSDictionary *_captureDeviceOutputSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
	_captureDeviceOutput.videoSettings = _captureDeviceOutputSettings;
	dispatch_queue_t _captureDeviceOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
	[_captureDeviceOutput setSampleBufferDelegate:self queue:_captureDeviceOutputQueue];
	
	// Конфигурирование AVCaptureSession
	[_captureSession beginConfiguration];
		[_captureSession addInput:_captureDeviceInput];
		[_captureSession addOutput:_captureDeviceOutput];
	[_captureSession commitConfiguration];
	
    // Хардкодим портретную ориентацию
    AVCaptureConnection *captureSessionConnect = [_captureDeviceOutput.connections firstObject];
    [captureSessionConnect setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
	// Запуск сессии
	[_captureSession startRunning];
	
	self.isInitialized = YES;
	return YES;
}

// Инициализация и запуск сессии захвата видео с камеры
- (bool)initializeVideoCapture {
	// Подбираем первую попавшуюся камеру
	AVCaptureDevice * someCameraDevice = nil;
	someCameraDevice = [self getFrontCameraDevice];
	if (!someCameraDevice)
		someCameraDevice = [self getBackCameraDevice];
	if (!someCameraDevice)
		someCameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	return [self initializeVideoCaptureWithDevice:someCameraDevice];
}

// Деинициализация сессии захвата видео с камеры
- (void)deinitializeVideoCapture {
	if (!_isInitialized)
		return;

	// Остановка сессии
	[_captureSession stopRunning];
    [_captureSession beginConfiguration];
        [_captureSession removeInput:_captureDeviceInput];
        [_captureSession removeOutput:_captureDeviceOutput];
    [_captureSession commitConfiguration];
	_isInitialized			= NO;
}

// Переключение камеры
- (bool)toggleCamera {
	bool result = false;
	
	// Запоминаем текущую выбранную камеру
	AVCaptureDevice * currentCameraDevice = self.captureDevice;
	
	// Деинициализация текущей сессии
	[self deinitializeVideoCapture];
	
	// Последней была задняя камеры - включаем переднюю
	if (currentCameraDevice == [self getBackCameraDevice])
		result = [self initializeVideoCaptureWithDevice: [self getFrontCameraDevice]];
	// Последней была передняя камера - включаем заднюю
	else if (currentCameraDevice == [self getFrontCameraDevice])
		result = [self initializeVideoCaptureWithDevice: [self getBackCameraDevice]];

	// Не получилось переключиться - пытаемся вернуть изначальную
	if (!result)
		return [self initializeVideoCaptureWithDevice: currentCameraDevice];
	return result;
}

/// ---
/// Делегированный метод AVCaptureVideoDataOutputSampleBufferDelegate (объект _captureDeviceOutput)
// Захвачен видео-кадр
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection 
{
	// Итоговый указатель на буфер
	unsigned char	*target_yuv420_buffer = NULL;
	size_t			target_width	= 0;
	size_t			target_height	= 0;

	// Необходимо выяснить - что содержит sampleBuffer, так как он может содержать комбинированные наборы данных
	CVImageBufferRef imageBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
	
	// Блокировка буфера изображения 
	CVPixelBufferLockBaseAddress(imageBufferRef, 0);

	// Работаем с изображением kCVPixelFormatType_32BGRA
	size_t	frameBufferWidth		= CVPixelBufferGetWidth(imageBufferRef);
	size_t	frameBufferHeight		= CVPixelBufferGetHeight(imageBufferRef);
	
	// Буфер, который будет содержать линейный YUV420, пригодный для кодирования
    // TODO : можно оптимизировать, так как malloc будет тратить время на выделение памяти в куче
	unsigned char *plain_yuv_buffer = (unsigned char*)malloc(frameBufferWidth * frameBufferHeight * 3 / 2);

	// Разбираем Y-plane
	size_t	y_plane_height		= CVPixelBufferGetHeightOfPlane(imageBufferRef, 0);
	size_t	y_plane_bprcnt		= CVPixelBufferGetBytesPerRowOfPlane(imageBufferRef, 0);
	void*	y_plane_baseaddr	= CVPixelBufferGetBaseAddressOfPlane(imageBufferRef, 0);
	memcpy(plain_yuv_buffer, y_plane_baseaddr, y_plane_bprcnt * y_plane_height);
	
	// Указатели в линейном буфере, по которым необходимо будет писать U и V, по отдельности
	unsigned char *plain_yuv_buffer_u = plain_yuv_buffer + frameBufferWidth * frameBufferHeight;
	unsigned char *plain_yuv_buffer_v = plain_yuv_buffer + frameBufferWidth * frameBufferHeight * 5 / 4;
	
	// Разбираем UV-plane
	// TODO оптимизировать этот разбор UV plane.
	// В libyuv есть функция для разделения перемешанного UV plane на два отдельных буфера
	// 1) Разделить libyuv
	// 2) Скопировать в plain_yuv_buffer U plane
	// 3) Скопировать в plain_yuv_buffer V plane
	void*	uv_plane_baseaddr	= CVPixelBufferGetBaseAddressOfPlane(imageBufferRef, 1);
	for(size_t it = 0; it < frameBufferWidth * frameBufferHeight / 4; it++)
	{
		plain_yuv_buffer_u[0] = *((unsigned char*)uv_plane_baseaddr);
		uv_plane_baseaddr++;
		plain_yuv_buffer_v[0] = *((unsigned char*)uv_plane_baseaddr);
		uv_plane_baseaddr++;
		plain_yuv_buffer_u++;
		plain_yuv_buffer_v++;
	}
	
	// Снятие блокировки буфера изображения 
	CVPixelBufferUnlockBaseAddress(imageBufferRef, 0); 
	
	// Итоговый буфер
	target_yuv420_buffer	= plain_yuv_buffer;
	target_width			= frameBufferWidth;
	target_height			= frameBufferHeight;
		
	// Оповещение подписчиков менеджера о получении кадра
	[_delegatesLock lock];
		for (NSObject <VideoCaptureManagerDelegate> *delegate in _delegates)
			if ([delegate respondsToSelector:@selector(videoCaptureManager:yuv420Received:yuv420BufferSize:yuv420Width:yuv420Height:)])
				[delegate videoCaptureManager:self yuv420Received:target_yuv420_buffer yuv420BufferSize:(target_width * target_height * 3 / 2) yuv420Width:target_width yuv420Height:target_height];
	[_delegatesLock unlock];
	free(target_yuv420_buffer);
}

@end
