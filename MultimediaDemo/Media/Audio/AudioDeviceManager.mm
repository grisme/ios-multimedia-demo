//
//  AudioDeviceManager.mm
//  MultimediaDemo
//
//  Created by Евгений Гарифуллин on 13.06.2018.
//  Copyright © 2018 Eugene Garifullin. All rights reserved.
//

#include <pthread.h>
#import "AudioDeviceManager.h"

/// Реализует простейший буфер воспроизведения. Безразмерный FIFO
class AudioRenderBuffer
{
public:
    // Конструктор
    AudioRenderBuffer(){
        pthread_mutex_init(&pcm_lock, 0);
        pcm_size = 0;
        pcm = (unsigned char*)malloc(pcm_size);
    }
    
    // Деструктор
    virtual ~AudioRenderBuffer(){
        if (pcm){
            pthread_mutex_lock(&pcm_lock);
            free(pcm);
            pcm = 0;
            pcm_size = 0;
            pthread_mutex_unlock(&pcm_lock);
        }
        pthread_mutex_destroy(&pcm_lock);
    }
    
    // Чтение данных из буфера
    void ReadPCMData(unsigned char *outPCMBuffer, unsigned int requiredDataSize){
        if (!outPCMBuffer || !requiredDataSize)
            return;
        
        pthread_mutex_lock(&pcm_lock);
        memset(outPCMBuffer, 0, requiredDataSize);
        unsigned int how_much_to_read = requiredDataSize;
        if (pcm_size < requiredDataSize)
            how_much_to_read = pcm_size;
        memcpy(outPCMBuffer, pcm, how_much_to_read);
        
        int new_size = pcm_size - how_much_to_read;
        unsigned char *new_pcm = (unsigned char*)malloc(new_size);
        memcpy(new_pcm, pcm + how_much_to_read, new_size);
        free(pcm);
        pcm = new_pcm;
        pcm_size = new_size;
        
        pthread_mutex_unlock(&pcm_lock);
    }
    
    // Запись данных в буфер
    void WritePCMData(const unsigned char *inPCMBuffer, unsigned int inPCMBufferSize){
        if (!inPCMBuffer || !inPCMBufferSize)
            return;
        
        pthread_mutex_lock(&pcm_lock);
        unsigned char *new_data = (unsigned char*)malloc(pcm_size + inPCMBufferSize);
        memcpy(new_data, pcm, pcm_size);
        memcpy(new_data + pcm_size, inPCMBuffer, inPCMBufferSize);
        free(pcm);
        pcm_size += inPCMBufferSize;
        pcm = new_data;
        pthread_mutex_unlock(&pcm_lock);
    }
    
    // Возвращает текущий размер буфера PCM в байтах
    unsigned int getCurrentPCMSize(){
        return pcm_size;
    }
    
private:
    unsigned char    *pcm;
    unsigned int    pcm_size;
    pthread_mutex_t pcm_lock;
};

/// Реализует объект аудио-процессинга, основанный на AudioUnit
class AudioUnitProcessor {
public:
    // Конструктор с передачей обратных вызовов в Objective-C менеджер аудио
    AudioUnitProcessor(id audioDeviceManager, SEL onCaptureSelector, SEL onRenderSelector){
        isInitialized = false;
        isStarted = false;
        isMuted = false;
        
        audioDeviceManagerInstance = audioDeviceManager;
        audioDeviceOnCapturedSelector = onCaptureSelector;
        audioDeviceOnRenderSelector = onRenderSelector;
    }
    
    // Деструктор
    ~AudioUnitProcessor(){
    	if (isStarted)
    		StopDevice();
        if (isInitialized)
            Deinitialize();
    }
    
    // Установка флага отключения микрофона 
    void setMuted(bool muted){
    	isMuted = muted;
	}
	// Возвращает флаг отключения микрофона
	bool getMuted(){
		return isMuted;
	}

    // Изменение пресета категорий и опций для AVAudioSession
    void ChangeAVAudioSessionPreset(AVAudioSessionCategoryOptions preset) {
    	
    	// Приостановка AudioUnit, так как сессию можно модифицировать только при приостановленных вводах-выводах
    	AudioOutputUnitStop(audioUnit);
    
    	// Изменение категории аудио-сессии
    	AVAudioSession *session = [AVAudioSession sharedInstance];
    	[session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:preset error:nil];
    	
    	// Запуск AudioUnit
    	AudioOutputUnitStart(audioUnit);
	}
    
    // Инициализация процессора аудио
    bool Initialize(AVAudioSessionCategoryOptions preset){
    
        if (isInitialized)
            return true;
		
		// Признак ошибки
        OSStatus error = noErr;
        
        // Создание AudioUnit с Voice Processing
        AudioComponentDescription desc = { kAudioUnitType_Output, kAudioUnitSubType_VoiceProcessingIO, kAudioUnitManufacturer_Apple, 0, 0 };
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        error = AudioComponentInstanceNew(comp, &audioUnit);
        if (error)
            return false;
        
        // Аргумент для передачи еденицы (для включения)
        UInt32 one; one = 1;
        
        // Включение ввода звука для нашего AudioUnit
        error = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, sizeof(one));
        if (error)
            return false;
        
        // Установка обратного вызова на захват звука
        AURenderCallbackStruct inInputProc;
        inInputProc.inputProcRefCon = this;
        inInputProc.inputProc = &AudioUnitProcessor::_s_input_callback;
        error = AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 1, &inInputProc, sizeof(inInputProc));
        if (error)
            return false;
        
        // Установка обратного вызова на воспроизведение звука
        AURenderCallbackStruct inRenderProc;
        inRenderProc.inputProcRefCon = this;
        inRenderProc.inputProc = &AudioUnitProcessor::_s_output_callback;
        // заполнить inRenderProc
        error = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inRenderProc, sizeof(inRenderProc));
        if (error)
            return false;
        
        // Установка звуковых параметров устройства захвата
        AudioStreamBasicDescription voiceIOFormat;
        voiceIOFormat.mBitsPerChannel       =    16;
        voiceIOFormat.mBytesPerFrame        =    2;
        voiceIOFormat.mBytesPerPacket       =    2;
        voiceIOFormat.mChannelsPerFrame     =    1;
        voiceIOFormat.mFormatFlags          =    kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        voiceIOFormat.mFormatID             =    kAudioFormatLinearPCM;
        voiceIOFormat.mFramesPerPacket      =    1;
        voiceIOFormat.mReserved             =    0;
        voiceIOFormat.mSampleRate           =    16000.0f;
        error = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &voiceIOFormat, sizeof(voiceIOFormat));
        if (error)
            return false;
            		
        // Установка звуковых параметров устройства воспроизведения
        voiceIOFormat.mBitsPerChannel       =    16;
        voiceIOFormat.mBytesPerFrame        =    2;
        voiceIOFormat.mBytesPerPacket       =    2;
        voiceIOFormat.mChannelsPerFrame     =    1;
        voiceIOFormat.mFormatFlags          =    kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        voiceIOFormat.mFormatID             =    kAudioFormatLinearPCM;
        voiceIOFormat.mFramesPerPacket      =    1;
        voiceIOFormat.mReserved             =    0;
        voiceIOFormat.mSampleRate           =    16000.0f;
        error = AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &voiceIOFormat, sizeof(voiceIOFormat));
        if (error)
            return false;
                        
		// Установка пресета
        AVAudioSession *session = [AVAudioSession sharedInstance];
    	[session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:preset error:nil];
     		
        isInitialized = true;
        return true;
    }
    
    // Деинициализация аудио-процессора
    void Deinitialize(){
        if (!isInitialized)
            return;
        
        // Разрушение инстанса audioUnit
        AudioComponentInstanceDispose(audioUnit);
    
        // Сбрасываем признак инициализации
        isInitialized = false;
    }
    
    // Производит запуск воспроизведения и захвата
    bool StartDevice(){
        
        if (isStarted)
        	return true;
        
        OSStatus error = noErr;
        
        // Финальная инициализация AudioUnit
        error = AudioUnitInitialize(audioUnit);
        if (error)
            return false;
        
        // Запуск процессинга аудио
        error = AudioOutputUnitStart(audioUnit);
        if (error){
            AudioUnitUninitialize(audioUnit);
            return false;
        }
        
        // Активация сессии AVAudioSession
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:YES error:nil];
        
        isStarted = true;
        
        return true;
    }
    
    // Производит остановку воспроизведения и захвата
    void StopDevice(){
    	
    	if (!isStarted)
        	return;
    
        // Остановка audioUnit
        AudioOutputUnitStop(audioUnit);
        // Деинициализация audioUnit
        AudioUnitUninitialize(audioUnit);
        
        // Изменение активного состояния аудио-сесссии на неактивное
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setActive:NO error:0];
        
        isStarted = false;
    }
    
    // ---
    // Обратные вызовы
    // Обратный вызов для захвата
    static OSStatus _s_input_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
        return ((AudioUnitProcessor*)inRefCon)->_d_input_callback(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    }
    OSStatus _d_input_callback(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
        
        // Подготовка буфера для вытягивания захваченного аудио
        AudioBuffer buffer;
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = inNumberFrames * 2;
        buffer.mData = malloc( inNumberFrames * 2 );

        // Подготовка списка буферов для вытягивания захваченного аудио
        AudioBufferList bufferList;
        bufferList.mNumberBuffers = 1;
        bufferList.mBuffers[0] = buffer;

        // Вытягивание аудио
        OSStatus error;
        error = AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList);
        if (!error){
            // Разбиение по порциям и вызов процессинга кусков дальше по цепочке
            unsigned int expect_frame_size = 640;
            unsigned char *expect_frame_buffer = (unsigned char*)malloc(expect_frame_size);
            captureBuffer.WritePCMData((const unsigned char*)buffer.mData, (unsigned int)buffer.mDataByteSize);
            while (captureBuffer.getCurrentPCMSize() >= expect_frame_size){
                captureBuffer.ReadPCMData(expect_frame_buffer, expect_frame_size);
                if (isMuted) memset(expect_frame_buffer, 0, expect_frame_size);
                
                // У нас демо-проект, вместо событийной модели складываем все в буфер для рендера
                // process_audioDeviceManagerCaptureSelector((const unsigned char*)expect_frame_buffer, expect_frame_size);
                renderBuffer.WritePCMData((const unsigned char*)expect_frame_buffer, expect_frame_size);
            }
            free(expect_frame_buffer);
        }

        if (buffer.mData)
            free(bufferList.mBuffers[0].mData);
        return noErr;
    }
    
    // Обратный вызов на воспроизведение звука
    static OSStatus _s_output_callback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
        return ((AudioUnitProcessor*)inRefCon)->_d_output_callback(ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, ioData);
    }
    OSStatus _d_output_callback(AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData){
        OSStatus result = noErr;
        memset(ioData->mBuffers[0].mData, 0, ioData->mBuffers[0].mDataByteSize);
        
        // У нас демо-проект, вместо событийной модели складываем вычитываем буфер для рендера
        // this->process_audioDeviceManagerRenderSelector((unsigned char*)ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
        renderBuffer.ReadPCMData((unsigned char*)ioData->mBuffers[0].mData, ioData->mBuffers[0].mDataByteSize);
        return result;
    }
    
private:
    // Инстанс AudioUnit, к которому привязывается ввод и вывод + аудио-процессинг Apple
    AudioUnit audioUnit;
    // Признак инициализации
    bool      isInitialized;
    bool      isStarted;	
    
    // Признак отключения микрофона
	bool		isMuted;

    // Простейший накопительный буфер для захвата (для кодирования и передачи аудио нужны ровные порции)
    AudioRenderBuffer captureBuffer;
    // Так как это демо приложение, то будем при захвате звука складывать данные в этот буфер. При воспроизведении брать из него
    AudioRenderBuffer renderBuffer;
    
    // Объект состояния и селектор для обратного вызова в менеджер аудио-устройства Objective C
    id audioDeviceManagerInstance;
    SEL audioDeviceOnCapturedSelector;
    SEL audioDeviceOnRenderSelector;
    
    void process_audioDeviceManagerCaptureSelector(const unsigned char *pcm, unsigned int pcmLength){
        IMP method = [audioDeviceManagerInstance methodForSelector:audioDeviceOnCapturedSelector];
        typedef int (*methodTypeName)(id, SEL, const unsigned char*, unsigned int);
        methodTypeName methodBlock = reinterpret_cast<methodTypeName>(method);
        methodBlock(audioDeviceManagerInstance, audioDeviceOnCapturedSelector, pcm, pcmLength);
    }
    
    void process_audioDeviceManagerRenderSelector(unsigned char *pcm, unsigned int pcmLength){
        IMP method = [audioDeviceManagerInstance methodForSelector:audioDeviceOnRenderSelector];
        typedef int (*methodTypeName)(id, SEL, const unsigned char*, unsigned int);
        methodTypeName methodBlock = reinterpret_cast<methodTypeName>(method);
        methodBlock(audioDeviceManagerInstance, audioDeviceOnRenderSelector, pcm, pcmLength);
	}
};

/// Реализация менеджера аудио-устройства
@implementation AudioDeviceManager {
    AudioUnitProcessor *audioUnitProcessor;
}

// Инициализатор
- (id)init {
    self = [super init];
    if (self){
		// Инициализация аттрибутов
        self.delegate = nil;
    
        // Создание процессора аудио AudioUnitProcessor
        audioUnitProcessor = new AudioUnitProcessor(self, @selector(capturedPCM:pcmLength:), @selector(renderingPCM:pcmLength:));
    }
    return self;
}

// Деинициализатор
- (void)dealloc {
	// Деинициализация и разрушение процессора аудио AudioUnitProcessor
    audioUnitProcessor->Deinitialize();
    delete audioUnitProcessor;
}

// Производит добавление подписчика в коллекцию делегатов
- (void)delegateAppend:(NSObject<AudioDeviceManagerDelegate>*)delegate {
    self.delegate = delegate;
}

// Производит удаление подписчика из коллекции делегатов
- (void)delegateRemove:(NSObject<AudioDeviceManagerDelegate> *)delegate {
    (void)delegate;
    self.delegate = nil;
}

// Возвращает признак разрешил ли пользователь доступ к захвату с микрофона 
+ (BOOL)isRecordingAllowed {
	return [AVAudioSession sharedInstance].recordPermission == AVAudioSessionRecordPermissionGranted;
}

// Установка флага отключения микрофона
- (void)setIsMuted:(BOOL)isMuted {
	audioUnitProcessor->setMuted(isMuted);
}

// Возвращает значение флага отключения микрофона
- (BOOL)getIsMuted {
	return audioUnitProcessor->getMuted();
}

// Изменение пресета для AVAudioSession (поведение приложения при работе со звуком)
// Рекомендуется использовать define'ы из списка
// AVAUDIOSESSION_PRESET_VOICECHAT_SPEAKER
// AVAUDIOSESSION_PRESET_VOICECHAT_RECEIVER
- (void)changeAudioSessionPreset:(AVAudioSessionCategoryOptions)preset {
	audioUnitProcessor->ChangeAVAudioSessionPreset(preset);
}

// Производит инициализацию дуплекс-аудио-устройства
- (BOOL)initializeDevice:(AVAudioSessionCategoryOptions)preset {
    return audioUnitProcessor->Initialize(preset);
}

// Производит деинициализацию дуплекс-аудио-устройства
- (void)deinitializeDevice {
    audioUnitProcessor->Deinitialize();
}

- (BOOL)startDevice {
    return audioUnitProcessor->StartDevice();
}

- (void)stopDevice {
    return audioUnitProcessor->StopDevice();
}

// Селектор, вызываемый при захвате аудио
- (void)capturedPCM:(const unsigned char *)pcm pcmLength:(unsigned int)pcmLength{
    if ([self.delegate respondsToSelector:@selector(audioDeviceManager:captured:pcmLength:)])
        [self.delegate audioDeviceManager:self captured:pcm pcmLength:pcmLength];
}

// Селектор вызываемый при воспроизведении аудио
- (void)renderingPCM:(unsigned char *)pcm pcmLength:(unsigned int)pcmLength {
    if ([self.delegate respondsToSelector:@selector(audioDeviceManager:required:pcmLength:)])
        [self.delegate audioDeviceManager:self required:pcm pcmLength:pcmLength];
}

@end
