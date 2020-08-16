#pragma once

///	Компонент изображения YUV (Y, U, V)
typedef struct
{
    int				w;				// Ширина кадра
    int				h;				// Высота кадра (количество строк)
    int				lineStride;		// Разрешение сроки (количество байт на строку)
    int				pixelStride;    // Разрешение пиксела (количество байт на пиксел)
    unsigned char*  buff;			// Указатель на линейный буфер
} component;

///	Описывает изображение в формате YUV
typedef struct
{
    component   Y, U, V;
} YUV_frame;

///
///	Перечисление FOURCC изображений в формате для YUV
typedef enum
{
    YV12, IF09, YVU9, IYUV,
    UYVY, YUY2, YVYU, HDYC,
    Y42B, I420, YV16, YV24,
    Y41B
} formats;

///
///	Помощник представления линейного буфера в формате YUV
class YUVHelper
{
public:
    ///
    /// Формирует YUV_frame из входящего буфера
    static int YUV_frame_from_buffer(YUV_frame* frame, unsigned char* buffer, const int w, const int h, const formats format);
};
