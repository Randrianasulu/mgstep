/*
   PSOperators.h

   Postscript single operator functions

   Copyright (C) 1999 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Mar 1999

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#ifndef _mGSTEP_H_PSOperators
#define _mGSTEP_H_PSOperators

typedef struct _DPSContext * DPSContext;


extern void PSnewpath(void);					
extern void PSclosepath(void);
extern void PScurveto(float x1,float y1, float x2,float y2, float x3,float y3);
extern void PSfill(void);
extern void PSlineto(float x, float y);
extern void PSmoveto(float x, float y);
extern void PSgrestore(void);
extern void PSgsave(void);
extern void PSrectclip(float a, float b, float c, float d);
extern void PSrlineto(float x, float y);
extern void PSsetgray(float num);
extern void PSshow(const char *str);
extern void PSstroke(void);
extern void PStranslate(float x, float y);

extern void PSsetmiterlimit(float limit);
extern void PSsetflat(float flatness);
extern void PSsetlinecap(int lineCap);
extern void PSsetlinejoin(int joinStyle);
extern void PSsetlinewidth(float width);
extern void PSsetdash(CGFloat pattern[], int size, CGFloat offset);
extern void PSeofill(void);
extern void PSfill(void);
extern void PSclip(void);
extern void PSeoclip(void);
extern void PSinitclip(void);

extern void PScomposite(float src_x, float src_y, float width, float height,
						int srcGstate,
						float dst_x, float dst_y,
						int op);

extern void PSdissolve( float src_x, float src_y, float width, float height,
						int srcGstate,
						float dst_x, float dst_y,
						float delta);



extern void DPScomposite( DPSContext ctxt,
                          float x, float y, float w, float h,
                          int gstateNum,
                          float dx, float dy,
                          int op);

extern void DPSdissolve( DPSContext ctxt,
						 float x, float y, float w, float h,
						 int gstateNum,
						 float dx, float dy,
						 float delta);

extern void DPSsetgray(DPSContext ctxt, float g);
extern void DPSsethsbcolor(DPSContext ctxt, float h, float s, float b);
extern void DPSmoveto(DPSContext ctxt, float x, float y);
extern void DPSlineto(DPSContext ctxt, float x, float y);
extern void DPSshow(DPSContext ctxt, const char *str);

extern void DPSrectfill(DPSContext ctxt, float x, float y, float w, float h);
extern void DPSrectstroke(DPSContext ctxt, float x, float y, float w, float h);

extern void DPScompositerect( DPSContext ctxt,
                              float x, float y, float w, float h,
                              int op);

#endif /* _mGSTEP_H_PSOperators */
