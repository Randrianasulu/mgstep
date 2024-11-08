/***************************************************************************/
/*                                                                         */
/*  hbshim.c                                                               */
/*                                                                         */
/*    HarfBuzz interface for accessing OpenType features (body).           */
/*                                                                         */
/*  Copyright 2013-2015 by                                                 */
/*  David Turner, Robert Wilhelm, and Werner Lemberg.                      */
/*                                                                         */
/*  This file is part of the FreeType project, and may only be used,       */
/*  modified, and distributed under the terms of the FreeType project      */
/*  license, LICENSE.TXT.  By continuing to use, modify, or distribute     */
/*  this file you indicate that you have read the license and              */
/*  understand and accept it fully.                                        */
/*                                                                         */
/***************************************************************************/


#include <ft2build.h>
#include FT_FREETYPE_H
#include "afglobal.h"
#include "aftypes.h"
#include "hbshim.h"

#ifdef FT_CONFIG_OPTION_USE_HARFBUZZ


#else /* !FT_CONFIG_OPTION_USE_HARFBUZZ */


  FT_Error
  af_get_coverage( AF_FaceGlobals  globals,
                   AF_StyleClass   style_class,
                   FT_Byte*        gstyles )
  {
    FT_UNUSED( globals );
    FT_UNUSED( style_class );
    FT_UNUSED( gstyles );

    return FT_Err_Ok;
  }


  FT_Error
  af_get_char_index( AF_StyleMetrics  metrics,
                     FT_ULong         charcode,
                     FT_ULong        *codepoint,
                     FT_Long         *y_offset )
  {
    FT_Face  face;


    if ( !metrics )
      return FT_THROW( Invalid_Argument );

    face = metrics->globals->face;

    *codepoint = FT_Get_Char_Index( face, charcode );
    *y_offset  = 0;

    return FT_Err_Ok;
  }


#endif /* !FT_CONFIG_OPTION_USE_HARFBUZZ */


/* END */
