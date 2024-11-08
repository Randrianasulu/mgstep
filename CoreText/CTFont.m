/*
   CTFont.m

   mini Core Text font.

   Copyright (C) 2018 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2018

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSData.h>
#include <Foundation/NSString.h>

#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreText/CTFont.h>

#include <math.h>

#ifndef USE_SYS_FREETYPE
  #include <ft2build.h>
///#include <ftconfig.h>	  // special ftconfig.h file, not the standard one
  #include FT_INTERNAL_DEBUG_H
  #include FT_SYSTEM_H
  #include FT_ERRORS_H
  #include FT_TYPES_H
  #include FT_INTERNAL_STREAM_H
#endif


CTFontRef
CTFontCreateWithName(CFStringRef name, CGFloat size, const CGAffineTransform *m)
{
    return CTFontCreateWithNameAndOptions(name, size, m, 0);
}

CTFontRef
CTFontCreateWithNameAndOptions( CFStringRef name,
								CGFloat size,
								const CGAffineTransform *m,
								CTFontOptions options)
{
	// determine path from name
	NSString *path;

//	FT_Stream_Open()	builds/unix/ftsystem.c
	NSData *d = [[NSData alloc] initWithContentsOfMappedFile:path];
//	if (!(_data = [[NSData alloc] initWithContentsOfMappedFile:path]))

	// open platform font
//	font = (NSFont*)CGFontCreateWithPlatformFont (fonti);

	// point size = size or kCTFontSystemFontSize
	// descriptor = NSFontDescriptor
 
    return NULL;
}

#ifndef USE_SYS_FREETYPE

//BOOL
//CTFontGetGlyphsForCharacters( CTFontRef f,
//							  const UniChar chars[],
//							  CGGlyph glyphs[],
//							  CFIndex count )		{ FIX ME in CGContext }

FT_BASE_DEF( FT_Error )
FT_Stream_Open( FT_Stream stream, const char *filepathname )
{
	NSData *d;
	NSString *path;

	if ( !stream )
		return FT_THROW( Invalid_Stream_Handle );

	path = [NSString stringWithCString: filepathname];
	if (!(d = [[NSData alloc] initWithContentsOfMappedFile:path]))
		{
		stream->base = NULL;
		stream->size = 0;
		stream->pos  = 0;

		return FT_THROW( Cannot_Open_Stream );
		}

    stream->size = (unsigned long)[d length];
    stream->pos  = 0;
    stream->base = (unsigned char *)[d bytes];
    stream->descriptor.pointer = stream->base;
    stream->pathname.pointer   = (char*)filepathname;
    stream->read = 0;

    return FT_Err_Ok;
}

FT_CALLBACK_DEF( void* )
ft_alloc( FT_Memory  memory, long size )
{
    FT_UNUSED( memory );

    return malloc( size );
}

FT_CALLBACK_DEF( void* )
ft_realloc( FT_Memory memory, long cur_size, long new_size, void *block )
{
    FT_UNUSED( memory );
    FT_UNUSED( cur_size );

    return realloc( block, new_size );
}

FT_CALLBACK_DEF( void )
ft_free( FT_Memory memory, void *block )
{
	FT_UNUSED( memory );

	free( block );
}

FT_BASE_DEF( FT_Memory )
FT_New_Memory( void )
{
	FT_Memory  memory;

	if ( (memory = (FT_Memory)malloc( sizeof ( *memory ) )) )
		{
		memory->user    = 0;
		memory->alloc   = ft_alloc;
		memory->realloc = ft_realloc;
		memory->free    = ft_free;
#ifdef FT_DEBUG_MEMORY
		ft_mem_debug_init( memory );
#endif
		}

	return memory;
}

FT_BASE_DEF( void )
FT_Done_Memory( FT_Memory  memory )
{
#ifdef FT_DEBUG_MEMORY
	ft_mem_debug_done( memory );
#endif
	memory->free( memory, memory );
}

#endif  /* !USE_SYS_FREETYPE */


#if 0
void
LoadGlyph(const char *symbol)
{
  FT_ULong code = symbol[0];

  // For simplicity, use the charmap FreeType provides by default;
  // in most cases this means Unicode.
  FT_UInt index = FT_Get_Char_Index(m_face, code);

  FT_Error error = FT_Load_Glyph(m_face,
                                 index,
                                 FT_LOAD_NO_SCALE | FT_LOAD_NO_BITMAP);

///  if (error)
///    throw runtime_error("Couldn't load the glyph: FT_Load_Glyph() failed");
}

// While working on this example, we found fonts with no outlines for
// printable characters such as `A', i.e., `outline.n_contours' and
// `outline.n_points' were zero.  FT_Outline_Check() returned `true'.
// FT_Outline_Decompose() also returned `true' without walking the outline.
// That is, we had no way of knowing whether the outline existed and could
// be (or was) decomposed.  Therefore, we implemented this workaround to
// check whether the outline does exist and can be decomposed.
BOOL
OutlineExists()
{
  FT_Face face = m_face;
  FT_GlyphSlot slot = face->glyph;
  FT_Outline &outline = slot->outline;

  if (slot->format != FT_GLYPH_FORMAT_OUTLINE)
    return false; // Should never happen.  Just an extra check.

  if (outline.n_contours <= 0 || outline.n_points <= 0)
    return false; // Can happen for some font files.

  FT_Error error = FT_Outline_Check(&outline);

  return error == 0;
}

// This function flips outline around x-axis. We need it because
// FreeType and SVG use opposite vertical directions.
void FlipOutline()
{
  const FT_Fixed multiplier = 65536L;

  FT_Matrix matrix;

  matrix.xx = 1L * multiplier;
  matrix.xy = 0L * multiplier;
  matrix.yx = 0L * multiplier;
  matrix.yy = -1L * multiplier;

  FT_Face face = m_face;
  FT_GlyphSlot slot = face->glyph;
  FT_Outline &outline = slot->outline;

  FT_Outline_Transform(&outline, &matrix);
}

int
MoveToFunction(const FT_Vector *to, void *user)
{
  OutlinePrinter *self = static_cast<OutlinePrinter *>(user);

  FT_Pos x = to->x;
  FT_Pos y = to->y;

  self->m_path << "           "
                  "M " << x << ' ' << y << '\n';

  return 0;
}

int
LineToFunction(const FT_Vector *to, void *user)
{
  OutlinePrinter *self = static_cast<OutlinePrinter *>(user);

  FT_Pos x = to->x;
  FT_Pos y = to->y;

  self->m_path << "           "
                  "L " << x << ' ' << y << '\n';

  return 0;
}

int
ConicToFunction(const FT_Vector *control,
				const FT_Vector *to,
				void *user)
{
  OutlinePrinter *self = static_cast<OutlinePrinter *>(user);

  FT_Pos controlX = control->x;
  FT_Pos controlY = control->y;

  FT_Pos x = to->x;
  FT_Pos y = to->y;

  self->m_path << "           "
                  "Q " << controlX << ' ' << controlY << ", "
                       << x << ' ' << y << '\n';

  return 0;
}

int
CubicToFunction(const FT_Vector *controlOne,
				const FT_Vector *controlTwo,
				const FT_Vector *to,
				void *user)
{
  OutlinePrinter *self = static_cast<OutlinePrinter *>(user);

  FT_Pos controlOneX = controlOne->x;
  FT_Pos controlOneY = controlOne->y;

  FT_Pos controlTwoX = controlTwo->x;
  FT_Pos controlTwoY = controlTwo->y;

  FT_Pos x = to->x;
  FT_Pos y = to->y;

  self->m_path << "           "
                  "C " << controlOneX << ' ' << controlOneY << ", "
                       << controlTwoX << ' ' << controlTwoY << ", "
                       << x << ' ' << y << '\n';

  return 0;
}

void
ExtractOutline()
{
///  m_path << "  <path d='\n";

  FT_Outline_Funcs callbacks;

  callbacks.move_to = MoveToFunction;
  callbacks.line_to = LineToFunction;
  callbacks.conic_to = ConicToFunction;
  callbacks.cubic_to = CubicToFunction;

  callbacks.shift = 0;
  callbacks.delta = 0;

  FT_Face face = m_face;
  FT_GlyphSlot slot = face->glyph;
  FT_Outline &outline = slot->outline;

  FT_Error error = FT_Outline_Decompose(&outline, &callbacks, this);

///  if (error)
///    throw runtime_error("Couldn't extract the outline:"
///                        " FT_Outline_Decompose() failed");

///  m_path << "          '\n"
///            "        fill='red'/>\n";
}

void
ComputeViewBox()
{
  FT_Face face = m_face;
  FT_GlyphSlot slot = face->glyph;
  FT_Outline &outline = slot->outline;

  FT_BBox boundingBox;

  FT_Outline_Get_BBox(&outline, &boundingBox);

  FT_Pos xMin = boundingBox.xMin;
  FT_Pos yMin = boundingBox.yMin;
  FT_Pos xMax = boundingBox.xMax;
  FT_Pos yMax = boundingBox.yMax;

  m_xMin = xMin;
  m_yMin = yMin;
  m_width = xMax - xMin;
  m_height = yMax - yMin;
}

void
PrintSVG()
{
  cout << "<svg xmlns='http://www.w3.org/2000/svg'\n"
          "     xmlns:xlink='http://www.w3.org/1999/xlink'\n"
          "     viewBox='"
       << m_xMin << ' ' << m_yMin << ' ' << m_width << ' ' << m_height
       << "'>\n"
       << m_path.str()
       << "</svg>"
       << endl;
}
#endif

CGPathRef
CTFontCreatePathForGlyph( CTFontRef f, CGGlyph g, const CGAffineTransform *m)
{
#if 0
  LoadGlyph(symbol);

  // Check whether outline exists.
  BOOL outlineExists = OutlineExists();

  if (!outlineExists) // Outline doesn't exist.
    throw runtime_error("Outline check failed.\n"
                        "Please, inspect your font file or try another one,"
                        " for example LiberationSerif-Bold.ttf");
  FlipOutline();

  ExtractOutline();

  ComputeViewBox();

  PrintSVG();
#endif

	return NULL;
}
