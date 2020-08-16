#include "YUVImage.h"
#include <stdlib.h>	
#include <string.h>

int YUVHelper::YUV_frame_from_buffer(YUV_frame* frame, unsigned char* buffer, const int w, const int h, const formats format)
{
    if (buffer == NULL)
        return 0;

    if ((w < 1) || (h < 1))
        return 0;

    frame->Y.w = w;
    frame->Y.h = h;

    switch (format)
    {
		case YV12: case IF09: case YVU9: case IYUV:
		case Y42B: case I420: case YV16: case YV24:
		case Y41B:
			frame->Y.pixelStride = 1;
			break;
		case UYVY: case YUY2: case YVYU: case HDYC:
			frame->Y.pixelStride = 2;
			break;
		default:
			return 0;
    }

    frame->Y.lineStride = w * frame->Y.pixelStride;
    frame->U = frame->Y;

    switch (format)
    {
		case UYVY: case YUY2: case YVYU: case HDYC:
			if (w % 2 != 0)
				return 0;
			frame->U.w = w / 2;
			frame->U.pixelStride = frame->Y.pixelStride * 2;
			break;
		case YV12: case IYUV: case I420:
			if (w % 2 != 0)
				return 0;
			if (h % 2 != 0)
				return 0;
			frame->U.w = w / 2;
			frame->U.h = h / 2;
			frame->U.lineStride = frame->Y.lineStride / 2;
			break;
		case IF09: case YVU9:
			if (w % 4 != 0)
				return 0;
			if (h % 4 != 0)
				return 0;
			frame->U.w = w / 4;
			frame->U.h = h / 4;
			frame->U.lineStride = frame->Y.lineStride / 4;
			break;
		case Y42B: case YV16:
			if (w % 2 != 0)
				return 0;
			frame->U.w = w / 2;
			frame->U.lineStride = frame->Y.lineStride / 2;
			break;
		case Y41B:
			if (w % 4 != 0)
				return 0;
			frame->U.w = w / 4;
			frame->U.lineStride = frame->Y.lineStride / 4;
			break;
		case YV24:
			break;
		default:
			return 0;
    }
    frame->V = frame->U;

    switch (format)
    {
		case UYVY: case HDYC:
			frame->U.buff = buffer;
			frame->Y.buff = frame->U.buff + 1;
			frame->V.buff = frame->U.buff + 2;
			break;
		case YUY2:
			frame->Y.buff = buffer;
			frame->U.buff = frame->Y.buff + 1;
			frame->V.buff = frame->Y.buff + 3;
			break;
		case YVYU:
			frame->Y.buff = buffer;
			frame->U.buff = frame->Y.buff + 3;
			frame->V.buff = frame->Y.buff + 1;
			break;
		case IYUV: case IF09: case YVU9: case Y42B: case I420: case Y41B:
			frame->Y.buff = buffer;
			frame->U.buff = frame->Y.buff + (frame->Y.lineStride * frame->Y.h);
			frame->V.buff = frame->U.buff + (frame->U.lineStride * frame->U.h);
			break;
		case YV12: case YV16: case YV24:
			frame->Y.buff = buffer;
			frame->V.buff = frame->Y.buff + (frame->Y.lineStride * frame->Y.h);
			frame->U.buff = frame->V.buff + (frame->V.lineStride * frame->V.h);
			break;
		default:
			return 0;
    }
    return 1;
}
