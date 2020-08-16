//
//  CoreViewController.m
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import "CoreViewController.h"

/// Реализует контроллер основного представления приложения
/// -------------------------------------------------------
@interface CoreViewController ()
@property (weak, nonatomic) IBOutlet UIButton *cameraSwitchButton;
@property (weak, nonatomic) IBOutlet UIButton *microphoneSwitchButton;
@property (weak, nonatomic) IBOutlet UIButton *hintButton;
@property (strong, nonatomic) IBOutlet UIView *coreView;
@end

@implementation CoreViewController {
    // Менеджер захвата с камеры
    VideoCaptureManager * videoCaptureManager;
    // Менеджер захвата и воспроизведения звука
    AudioDeviceManager * audioDeviceManager;
}

/// Обработка события - представление загружено
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Инициализация UI
    [self initializeUI];
}

/// Возвращает предпочтительную ориентацию для представления на устройстве
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

/// Возвращает стиль статус бара на данном представлении
- (UIStatusBarStyle)preferredStatusBarStyle {
    // Так как контент представления предпочтительно темный,
    // устанавливаем стиль контента статус бара в светлый
    return UIStatusBarStyleLightContent;
}

/// Инициализация пользовательского интерфейса
- (void)initializeUI {
    // Общие установки для внешнего вида кнопок нижней панели
    CGFloat buttonBorderRadius = 16.0f;  // Радиус скругления границ кнопки
    CGFloat buttonBorderWidth = 2.0f;   // Толщина границ кнопки
    CGColorRef buttonBorderColor = [[UIColor whiteColor] CGColor]; // Цвет границы кнопки
    
    // Установка параметров внешнего вида кнопки переключения камеры
    self.cameraSwitchButton.layer.borderColor = buttonBorderColor;
    self.cameraSwitchButton.layer.borderWidth = buttonBorderWidth;
    self.cameraSwitchButton.layer.cornerRadius = buttonBorderRadius;
    
    // Установка параметров внешнего вида и состояния кнопки включения / выключения микрофона
    [self.microphoneSwitchButton setSelected: NO];
    self.microphoneSwitchButton.layer.borderColor = buttonBorderColor;
    self.microphoneSwitchButton.layer.borderWidth = buttonBorderWidth;
    self.microphoneSwitchButton.layer.cornerRadius = buttonBorderRadius;
    
    // Установка параметров внешнего вида кнопки "Подсказка"
    self.hintButton.layer.borderColor = buttonBorderColor;
    self.hintButton.layer.borderWidth = buttonBorderWidth;
    self.hintButton.layer.cornerRadius = buttonBorderRadius;
}

/// Обработка события - представление будет отображено
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    
    // Инициализация менеджера захвата с камеры и подписка на событие захвата RAW-кадра (добавление себя в коллекцию делегатов)
    videoCaptureManager = [[VideoCaptureManager alloc] init];
    [videoCaptureManager initializeVideoCapture];
    [videoCaptureManager delegateAppend: self];
    
    // Инициализация менеджера захвата и воспроизведения звука
    audioDeviceManager = [[AudioDeviceManager alloc] init];
    [audioDeviceManager initializeDevice: AVAUDIOSESSION_PRESET_VOICECHAT_SPEAKER];
    [audioDeviceManager startDevice];
}

/// Обработка события - представление будет скрыто
- (void)viewWillDisappear:(BOOL)animated {
    
    // Деинициализация менеджера захвата и воспроизведения звука
    [audioDeviceManager stopDevice];
    [audioDeviceManager deinitializeDevice];
    audioDeviceManager = nil;
    
    // Деинициализация менеджера захвата с камеры
    [videoCaptureManager delegateRemove: self];
    [videoCaptureManager deinitializeVideoCapture];
    videoCaptureManager = nil;
    
    [super viewWillDisappear: animated];
}

/// Обработка события - предупреждение системы о нехватке памяти
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/// Действие - сменить камеру
- (IBAction)cameraSwitchAction:(id)sender {
    // Переворачиваем камеру
    [videoCaptureManager toggleCamera];
}

/// Действие - включить / выключить микрофон
- (IBAction)microphoneSwitchAction:(id)sender {
    if (self.microphoneSwitchButton.isSelected){
        [self.microphoneSwitchButton setSelected: NO];
        self.microphoneSwitchButton.backgroundColor = nil;
    }
    else {
        [self.microphoneSwitchButton setSelected: YES];
        self.microphoneSwitchButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
    }
    [audioDeviceManager setIsMuted: self.microphoneSwitchButton.isSelected];
}

/// Действие - показать подсказку
- (IBAction)hintAction:(id)sender
{
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Подсказка"
                                          message:@"Данная демонстрационная программа производит относительно низкоуровневый захват с камеры и производит рендеринг кадра в главном представлении. Можно переключать камеру с передней на заднюю. Так же приложение производит относительно низкоуровневый захват с микрофона PCM-данных и воспроизводит их же в динамик, пропуская через встроенный модуль эхоподавления"
                                          preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Отлично" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action){
        [alertController dismissViewControllerAnimated:YES completion:^{}];
    }]];
    [self presentViewController:alertController animated:YES completion:^{}];
}

/// ---
/// Делегированные методы VideoCaptureManagerDelegate
/// Захвачен кадр с камеры
/// Данный метод выполнится НЕ в главной нити (для AVFoundation мы создаем отдельную нить при инициализации VideoCaptureManager).
/// Для отображения потребуется диспетчеризация в главную нить
- (void)videoCaptureManager:(id)captureManager yuv420Received:(const unsigned char *)yuvData yuv420BufferSize:(size_t)yuvDataSize yuv420Width:(size_t)width yuv420Height:(size_t)height {
    // Здесь можно было бы отправить захваченный кадр на кодирование и пересылку
    // Но поскольку это демо-приложение, будем отображать его в основном представлении
    
    // Буфер для ABGR-данных
    // Такое выделение в куче при рендере каждого кадра не является оптимальным решением
    // Во-первых, malloc может занимать достаточно длительное время, так как malloc ищет связанный блок памяти нужного размера
    // Во-вторых, результатом может вернуться NULL, если места для выделения памяти не хватит
    // Лучший вариант - держать заранее выделенный в куче буфер для кадра условно-максимального размера (например, 1920x1080x4 байт)
    unsigned char * abgrData = (unsigned char *)malloc(sizeof(unsigned char) * width * height * 4);
    
    // Конвертирование YUV420 в ABGR, который легко отрендерить в iOS
    [ImageUtils RawImage_YUV420toABGR:yuvData abgrData:abgrData width:width height:height];
    
    // Блок рендеринга
    dispatch_block_t render_block = ^{
        // установка CGImageRef в CALayer
        CGColorSpaceRef colorRGB    = CGColorSpaceCreateDeviceRGB();
        CGContextRef    context     = CGBitmapContextCreate(abgrData, width, height, 8 /* бит на пиксель */, 4 * width /* размер "строки" битмапа в байтах */, colorRGB, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
        CGImageRef      dstImage    = CGBitmapContextCreateImage(context);
        
        // Для CALayer можно установить парковку content'а - в данном случае заполнение всего bounds с сохранением соотношения сторон
        self.coreView.layer.contentsGravity = kCAGravityResizeAspectFill;
        self.coreView.layer.contents = (__bridge id)dstImage;
        
        CGImageRelease(dstImage);
        CGContextRelease(context);
        CGColorSpaceRelease(colorRGB);
    };
    // На всякий случай - проверка на исполнение в главной нити, чтобы не случился dead-lock
    if (NSThread.isMainThread)
        render_block();
    else
        // !!!!!!!!!!!!!
        // Синхронизация в main thread в данном демонстрационном примере приемлема, так как
        // ожидание нити, в которой происходит захват с камеры, некритично - камера сконфигурирована с пропуском "опоздавших" кадров
        // и задержка не создастся.
        // Могу объяснить более лучший способ, который применил на практике
        dispatch_sync(dispatch_get_main_queue(), render_block);
    
    // FIXME : смотри про malloc выше.
    free(abgrData);
    
}

@end
