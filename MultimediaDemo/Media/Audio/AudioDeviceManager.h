//
//  AudioDeviceManager.h
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

// Пресеты для установки категории на AVAudioSession
// Пресет для использования AudioSession в режиме госового вызова (с реакцией на датчик приближения), аудио направляется в ушной динамик, разрешен BlueTooth, с приглушением остальных
#define	AVAUDIOSESSION_PRESET_VOICECHAT_RECEIVER kAudioSessionMode_VoiceChat | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDuckOthers
// Пресет для использования AudioSession в режиме госового вызова (с реакцией на датчик приближения), аудио направляется во внешний динамик, разрешен BlueTooth, с приглушением остальных
#define AVAUDIOSESSION_PRESET_VOICECHAT_SPEAKER	 kAudioSessionMode_VoiceChat | AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionDuckOthers

#define AVAUDIOSESSION_PRESET_VOICECHAT_STANDALONE kAudioSessionMode_VoiceChat

@class AudioDeviceManager;

/// Реализует протокол делегирования событий менеджера аудио-устройства
@protocol AudioDeviceManagerDelegate
// Произведен захват аудио с микрофона
@optional - (void)audioDeviceManager:(AudioDeviceManager*)audioDeviceManager captured:(const unsigned char*)pcm pcmLength:(unsigned int)pcmLength;
// Требуется звук для воспроизведения
@optional - (void)audioDeviceManager:(AudioDeviceManager*)audioDeviceManager required:(unsigned char *)pcm pcmLength:(unsigned int)pcmLength;
@end

/// Реализует менеджер аудио-устройства
/// Используется и для захвата, и для воспроизведения звука
@interface AudioDeviceManager : NSObject

// Делегат обработки событий
@property (weak, atomic) NSObject <AudioDeviceManagerDelegate> *delegate;
- (void)delegateAppend: (NSObject <AudioDeviceManagerDelegate> *)delegate;
- (void)delegateRemove: (NSObject <AudioDeviceManagerDelegate> *)delegate;

// Инициализатор
- (id)init;

// Возвращает признак разрешения пользователем использования микрофона
+ (BOOL)isRecordingAllowed;

// Изменение пресета AVAudioSession
// Рекомендуется вызывать после инициализации initializeDevice
- (void)changeAudioSessionPreset:(AVAudioSessionCategoryOptions)preset;

// Производит инициализацию / деинициализацию аудио-устройства
// TODO возможно нужно передавать параметры аудио устройств (частоту дискретизации и прочее)
- (BOOL)initializeDevice:(AVAudioSessionCategoryOptions)preset;
- (void)deinitializeDevice;

// Запускает захват и воспроизведение
- (BOOL)startDevice;
- (void)stopDevice;

// Установка / изъятие флага приглушенности
- (void)setIsMuted:(BOOL)isMuted;
- (BOOL)getIsMuted;

// Селектор, вызываемый при захвате аудио
- (void)capturedPCM:(const unsigned char*)pcm pcmLength:(unsigned int)pcmLength;
// Селектор, вызываемый при воспроизведении аудио
- (void)renderingPCM:(unsigned char *)pcm pcmLength:(unsigned int)pcmLength;

@end
