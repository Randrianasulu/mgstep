/*
   CGFilter.m

   Image processing filters.

   Copyright (C) 2006-2019 Free Software Foundation, Inc.

   Author:  Felipe A. Rodriguez <far@illumenos.com>
   Date:    Jan 2006

   This file is part of the mGSTEP Library and is provided
   under the terms of the GNU Library General Public License.
*/

#include <Foundation/NSString.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFRuntime.h>
#include <CoreGraphics/CoreGraphics.h>


#define CTX				((CGContext *)cx)


/* ****************************************************************************

   Gaussian  1D
   
   g(x) = ( 1 / √2π * σ ) * e ^ ( -x² / 2σ² )

	σ - Sigma is the desired standard deviation
	e - Euler's number, 2.71828...

** ***************************************************************************/

static CGFloat _GaussianDistribution (CGFloat x, CGFloat sigma)
{
	CGFloat n = 1.0 / (sqrt(2. * M_PI) * sigma);

	return n * pow(M_E, -x*x / (2. * sigma * sigma));
}

/* ****************************************************************************

   _SampleIntegration() -- Simpson's rule integration
   
   Approximate the integral for domain [a,a+1] with a derivation combining the
   Reimann sum Midpoint rule 'm' and Trapezoidal rule 't' methods.
 
	a - start point of domain to integrate (spans thru a + 1)
	σ - Sigma is the desired standard deviation

** ***************************************************************************/

static CGFloat _SampleIntegration (CGFloat a, CGFloat sigma)
{
	CGFloat m = (_GaussianDistribution (a + 1./8., sigma)
			   + _GaussianDistribution (a + 3./8., sigma)
			   + _GaussianDistribution (a + 5./8., sigma)
			   + _GaussianDistribution (a + 7./8., sigma)) / 4;
	CGFloat t = (_GaussianDistribution (a, sigma)
			   + 2 * _GaussianDistribution (a + 1./4., sigma)
			   + 2 * _GaussianDistribution (a + 1./2., sigma)
			   + 2 * _GaussianDistribution (a + 3./4., sigma)
			   + _GaussianDistribution (a + 1., sigma)) / 8;

	return (2. * m + t) / 3.;
}

/* ****************************************************************************

   _CGMakeConvolutionKernel()

   Make a discrete kernel from its continous Gaussian distribution curve.
   Discrete kernel points are normalized (sum == 1) by distributing tail
   area outside the kernel as weights to its points.

	k - array of 'n' elements to store discrete kernel
	n - number of calculated points in discrete kernel
	σ - Sigma is the desired standard deviation

  Convolution kernel must be odd size (2n - 1), has peak weight at center

** ***************************************************************************/

CGFloat *_CGMakeConvolutionKernel (CGFloat *kernel, unsigned n, CGFloat sigma)
{
	memset(kernel, 0, sizeof(CGFloat) * n);

	if (n >= 3 && n <= 9 && sigma > 0)
		{
		CGFloat a = -.5;
		CGFloat weightSum;
		int right = n / 2 + 1;
		int i;

		for (i = 0; i < right; i++, a += 1.)		// calc discrete kernel pts
			kernel[i] = _SampleIntegration (a, sigma);
		weightSum = kernel[0];						// tail area outside kernel
		for (i = 1; i < right; i++)					// equals 1 - weightSum
			weightSum += (2 * kernel[i]);
		for (i = 0; i < right; i++)					// normalize kernel points
			kernel[i] = kernel[i] / weightSum;		// with tail area weight
		}											// kernel sum s/b == 1

	return kernel[0] > 0 ? kernel : NULL;
}

/* ****************************************************************************

   Fast Convolution with Packed Lookup Tables, C code from the article in
   Graphics Gems IV, Academic Press, 1994 by George Wolberg and Henry Massalin
   (wolcc@cunyvm.cuny.edu and qua@microunity.com), Public Domain usage terms.

** ***************************************************************************/

typedef struct {		/* packed lut structure	    */
	int lut0[256];		/* stage 0 for	5-pt kernel */
	int lut1[256];		/* stage 1 for 11-pt kernel */
	int lut2[256];		/* stage 2 for 17-pt kernel */
	int bias;		    /* accumulated stage biases */
	int stages;		    /* # of stages used: 1,2,3  */
} Lut;

#define MASK			0x3FF
#define ROUNDD			1
#define PACK(A,B,C)		(((A)<<20) + ((B)<<10) + (C))
#define INT(A)			((int) ((A)*262144+32768) >> 16)
#define CLAMP(A,L,H)	((A) <= (L) ? (L) : (A) <= (H) ? (A) : (H))
///#define ABS(A)		((A) >= 0 ? (A) : -(A))


/* ****************************************************************************

   initPackedLuts() -- Initialize scaled and packed lookup tables in lut.

   Permit up to 3 cascaded stages for the following kernel sizes:
  	stage 0:  5-point kernel
  	stage 1: 11-point kernel
  	stage 2: 17-point kernel
   lut->lut0 <== packed entries (i*k2, i*k1, .5*i*k0), for i in [0, 255]
   lut->lut1 <== packed entries (i*k5, i*k4,	i*k3), for i in [0, 255]
   lut->lut2 <== packed entries (i*k8, i*k7,	i*k6), for i in [0, 255]
   where k0,...k8 are taken in sequence from kernel[].
  
   Note that in lut0, k0 is halved since it corresponds to the center
   pixel's kernel value and it appears in both fwd0 and rev0 (see gem).

** ***************************************************************************/

static void
initPackedLuts(CGFloat *kernel, int n, Lut *luts)
{
	int	i, k, s, *lut;
	int	b1, b2, b3;
	float k1, k2, k3;
	float sum;

	/* enforce flat-field response constraint: sum of kernel values = 1 */
	sum = kernel[0];
	for(i=1; i<n; i++)
		sum += 2*kernel[i];			/* account for symmetry */
	if(ABS(sum - 1) > .001)
		fprintf(stderr, "Warning: filter sum != 1 (=%f)\n", sum);

	/* init bias added to fields to avoid negative numbers (underflow) */
	luts->bias = 0;

	/* set up lut stages, 3 kernel values at a time */
	for(k=s=0; k<n; s++) {			/* init lut (stage s)	*/
		k1 = (k < n) ? kernel[k++] : 0;
		k2 = (k < n) ? kernel[k++] : 0;
		k3 = (k < n) ? kernel[k++] : 0;
		if(k <= 3) k1 *= .5;		/* kernel[0]: halve k0	*/

		/* select proper array in lut structure based on stage s */
		switch(s) {
		case 0: lut = luts->lut0;	break;
		case 1: lut = luts->lut1;	break;
		case 2: lut = luts->lut2;	break;
		}

		/* check k1,k2,k3 to avoid overflow in 10-bit fields */
		if(ABS(k1) + ABS(k2) + ABS(k3) > 1)
			{
			fprintf(stderr, "|%f|+|%f|+|%f| > 1\n", k1, k2, k3);
			return;
			}

		/* compute bias for each field to avoid underflow */
		b1 = b2 = b3 = 0;
		if(k1 < 0) b1 = -k1 * 1024;
		if(k2 < 0) b2 = -k2 * 1024;
		if(k3 < 0) b3 = -k3 * 1024;

		/* luts->bias will be subtracted in convolve() after adding
		 * stages; multiply by 2 because of combined effect of fwd
		 * and rev terms
		 */
		luts->bias += 2*(b1 + b2 + b3);

		/* scale and pack kernel values in lut */
		for(i=0; i<256; i++) {
			/* INT(A) forms fixed point field: (A*(1<<18)+(1<<15)) >> 16 */
			lut[i] = PACK(	INT(i*k3) + b3,
							INT(i*k2) + b2 + ROUNDD,
							INT(i*k1) + b1 );
		}
	}
	luts->stages = s;
}

/* ****************************************************************************

   fastconv() -- Fast 1D convolver

   Convolve len input samples in src with a symmetric kernel packed in luts, a
   lookup table created by initPackedLuts() from kernel values, output to dst.

** ***************************************************************************/

static void
fastconv(unsigned char *src, int len, int stride, Lut *luts, unsigned char *dst)
{
	int	 x, padlen, val, bias;
	int	 fwd0, fwd1, fwd2;
	int	 rev0, rev1, rev2;
	int	*lut0, *lut1, *lut2;
	unsigned char	*p1, *p2, *ip, *op;
	unsigned char	 buf[1024];

	/* copy and pad src into buf with padlen elements on each end */
	padlen = 4*(luts->stages) - 1;
	p1 = src;		/* pointer to row (or column) of input	*/
	p2 = buf;		/* pointer to row of padded buffer	*/
	for(x=0; x<padlen; x++) /* pad left side: replicate first pixel */
		*p2++ = *p1;
	for(x=0; x<len; x++) {	/* copy input row (or column)		*/
		*p2++ = *p1;
		 p1  +=	 stride;
	}
	p1 -= stride;		/* point to last valid input pixel	*/
	p2 -= padlen - 1;
	for(x=0; x<padlen; x++) /* pad right side: replicate last pixel */
		*p2++ = *p1;

	/* initialize input and output pointers, ip and op, respectively */
	ip = buf;
	op = dst;

	/* bias was added to lut entries to deal with negative kernel values */
	bias = luts->bias;

	switch(luts->stages) {
	case 1:		/* 5-pt kernel */
		lut0 = luts->lut0;

		ip  += 2;	/* ip[0] is center pixel */
		fwd0 = (lut0[ip[-2]] >> 10) + lut0[ip[-1]];
		rev0 = (lut0[ip[ 0]] << 10) + lut0[ip[ 1]];

		while(len--) {
			fwd0 = (fwd0 >> 10) + lut0[ip[0]];
			rev0 = (rev0 << 10) + lut0[ip[2]];
			val = ((fwd0 & MASK) + ((rev0 >> 20) & MASK) - bias) >> 2;
			*op = CLAMP(val, 0, 255);

			ip++;
			op += stride;
		}
		break;
	case 2:		/* 11-pt kernel */
		lut0 = luts->lut0;
		lut1 = luts->lut1;

		ip  += 5;	/* ip[0] is center pixel */
		fwd0 = (lut0[ip[-2]] >> 10) + lut0[ip[-1]];
		rev0 = (lut0[ip[ 0]] << 10) + lut0[ip[ 1]];

		fwd1 = (lut1[ip[-5]] >> 10) + lut1[ip[-4]];
		rev1 = (lut1[ip[ 3]] << 10) + lut1[ip[ 4]];

		while(len--) {
			fwd0 = (fwd0 >> 10) + lut0[ip[0]];
			rev0 = (rev0 << 10) + lut0[ip[2]];

			fwd1 = (fwd1 >> 10) + lut1[ip[-3]];
			rev1 = (rev1 << 10) + lut1[ip[ 5]];

			val  =	((fwd0 & MASK) + ((rev0 >> 20) & MASK)
				+ (fwd1 & MASK) + ((rev1 >> 20) & MASK) - bias) >> 2;
			*op = CLAMP(val, 0, 255);

			ip++;
			op += stride;
		}
		break;
	case 3:		/* 17-pt kernel */
		lut0 = luts->lut0;
		lut1 = luts->lut1;
		lut2 = luts->lut2;

		ip  += 8;	/* ip[0] is center pixel */
		fwd0 = (lut0[ip[-2]] >> 10) + lut0[ip[-1]];
		rev0 = (lut0[ip[ 0]] << 10) + lut0[ip[ 1]];

		fwd1 = (lut1[ip[-5]] >> 10) + lut1[ip[-4]];
		rev1 = (lut1[ip[ 3]] << 10) + lut1[ip[ 4]];

		fwd2 = (lut2[ip[-8]] >> 10) + lut2[ip[-7]];
		rev2 = (lut2[ip[ 6]] << 10) + lut2[ip[ 7]];

		while(len--) {
			fwd0 = (fwd0 >> 10) + lut0[ip[0]];
			rev0 = (rev0 << 10) + lut0[ip[2]];

			fwd1 = (fwd1 >> 10) + lut1[ip[-3]];
			rev1 = (rev1 << 10) + lut1[ip[ 5]];

			fwd2 = (fwd2 >> 10) + lut2[ip[-6]];
			rev2 = (rev2 << 10) + lut2[ip[ 8]];

			val  =	((fwd0 & MASK) + ((rev0 >> 20) & MASK)
				+(fwd1 & MASK) + ((rev1 >> 20) & MASK)
				+(fwd2 & MASK) + ((rev2 >> 20) & MASK) - bias) >> 2;
			*op = CLAMP(val, 0, 255);

			ip++;
			op += stride;
		}
		break;
	}
}

/* ****************************************************************************

   convolve()

   Convolve input image ip with kernel, a (2n-1)-point symmetric filter kernel
   containing n entries: h[i] = kernel[ |i| ] for -n < i < n. Output at op.

** ***************************************************************************/

static void
convolve( CGImage *ip, CGFloat *kernel, int n, CGImage *op)
{
	CGImage ti = {0};
	int	x, y, w, h;
	unsigned char *src, *dst;
	Lut luts;

	ti.width = w = ip->width;			/* image width		*/
	ti.height = h = ip->height;			/* image height		*/

	ti.idata = malloc(w*h);				/* reserve tmp image	*/
	initPackedLuts(kernel, n, &luts);	/* init packed luts	*/

	for(y=0; y<h; y++) {				/* process all rows	*/
		src = ip->idata + y*w;			/* ptr to input	 row	*/
		dst = ti.idata + y*w;			/* ptr to output row	*/
		fastconv(src, w, 1, &luts, dst);/* w pixels; stride=1	*/
	}

	for(x=0; x<w; x++) {				/* process all columns	*/
		src = ti.idata + x;				/* ptr to input	 column */
		dst = op->idata + x;			/* ptr to output column */
		fastconv(src, h, w, &luts, dst);/* h pixels; stride=w	*/
	}

	free(ti.idata);						/* free temporary image */
}

void _CGContextDrawShadow(CGContextRef cx, CGRect r)
{
	CGFloat kernel[9];
	CGFloat *kp;
	int n = 4;

	if ((kp = _CGMakeConvolutionKernel(kernel, (2 * n - 1), 10)) != NULL)
		{
		CGImageRef ip;

		r = NSIntegralRect(r);
		r.origin.x = MAX(0, r.origin.x-7);	// shadow is too small w/o padding
		r.origin.y = MAX(0, r.origin.y-7);
		r.size.width += 14;
		r.size.height += 14;

		if ((ip = _CGContextGetImage(cx, r)))
			{
			CGImage mask = {0};
			CGImage pad  = {0};
			int row;

			mask.width  = pad.width  = r.size.width;
			mask.height = pad.height = r.size.height;
			pad.idata  = calloc(1, pad.width * pad.height);
			mask.idata = calloc(1, pad.width * pad.height);

			memset(pad.idata, 0xff, pad.width * pad.height);	// prep workpad
			for (row = 4; row < pad.height - 8; row++)
				memset(pad.idata+(row*pad.width+4), 0x00, pad.width - 8);
//			for (row = 1; row < t1.height - 1; row++)
//				memset(t1.image+(row*t2.width+1), 0x00, t2.width - 2);
			convolve( &pad, kp, n, &mask );				// generate alpha mask

			((CGImage *)ip)->_f.reuseSource = YES;
			_CGImageCreateWithColorMask(ip, &mask, CTX->_gs->_shadow.color);
			CGContextDrawImage(cx, r, ip);

			free(pad.idata);
			free(mask.idata);
			CGImageRelease(ip);
		}	}
}

/* ****************************************************************************

   Zoom filter derived from Filtered Image Rescaling in Graphics Gems III
   Public Domain 1991 by Dale Schumacher.

** ***************************************************************************/

#define	 box_support        (0.5)
#define	 triangle_support   (1.0)
#define	 bell_support		(1.5)
#define	 B_spline_support	(2.0)
#define	 Lanczos3_support	(3.0)
#define	 Mitchell_support   (2.0)

#define	BB	(1.0 / 3.0)
#define	CC	(1.0 / 3.0)


static double
box_filter(double t)
{
	return ((t > -0.5) && (t <= 0.5)) ? (1.0) : (0.0);
}

static double
triangle_filter(double t)
{
    if (t < 0.0)
		t = -t;

	return (t < 1.0) ? (1.0 - t) : (0.0);
}

static double
bell_filter(double t)		/* box (*) box (*) box */
{
    if (t < 0)
		t = -t;

    if (t < .5)
		return (.75 - (t * t));

    if (t < 1.5)
		{
		t = (t - 1.5);
		return (.5 * (t * t));
    	}

    return (0.0);
}

static double
B_spline_filter(double t)	/* box (*) box (*) box (*) box */
{
	double tt;
    
    if (t < 0)
		t = -t;

    if (t < 1)
		{
		tt = t * t;
		return ((.5 * tt * t) - tt + (2.0 / 3.0));
		}

	if (t < 2)
		{
		t = 2 - t;
		return ((1.0 / 6.0) * (t * t * t));
		}

    return (0.0);
}

static double
sinc(double x)
{
    x *= M_PI;

	return (x != 0) ? (sin(x) / x) : (1.0);
}

static double
Lanczos3_filter(double t)
{
    if (t < 0)
		t = -t;

	return (t < 3.0) ? (sinc(t) * sinc(t/3.0)) : (0.0);
}

static double
Mitchell_filter(double t)
{
	double tt = t * t;

    if (t < 0)
		t = -t;

    if (t < 1.0)
		{
		t = (((12.0 - 9.0 * BB - 6.0 * CC) * (t * tt))
			 + ((-18.0 + 12.0 * BB + 6.0 * CC) * tt)
			 + (6.0 - 2 * BB));
		return (t / 6.0);
		}

	if (t < 2.0)
		{
		t = (((-1.0 * BB - 6.0 * CC) * (t * tt))
			 + ((6.0 * BB + 30.0 * CC) * tt)
			 + ((-12.0 * BB - 48.0 * CC) * t)
			 + (8.0 * BB + 24 * CC));
		return (t / 6.0);
		}

    return (0.0);
}

static double (*__filterf)() = Mitchell_filter;		// box_filter, ...
static double __fwidth = Mitchell_support;			// must match filter in use

typedef struct {
    int     pixel;
    double	weight;
} Contrib;

typedef struct {
    int	n;								// number of contributors
    Contrib	*p;							// pointer to list of contributions
} Clist;

/* clamp the input to the specified range */
//#define CLAMP(v,l,h)    ((v) < (l) ? (l) : (v) > (h) ? (h) : v)


static Clist *
_ContributionsList( CGImageRef src, unsigned ls, unsigned sd, double scale )
{
	Clist *cl = (Clist *)calloc(ls, sizeof(Clist));	// contribution lists array
	int i, j, k, n;

    if (scale < 1.0)			// pre-calculate filter contributions for a row
		{
		double width = __fwidth / scale;
		double fscale = 1.0 / scale;

		for (i = 0; i < ls; ++i)
			{
			double center = (double) i / scale;
			double left = ceil(center - width);
			double right = floor(center + width);

			cl[i].n = 0;
			cl[i].p = (Contrib *)calloc((int)(width * 2 + 1), sizeof(Contrib));

			for(j = left; j <= right; ++j)
				{
				double weight = center - (double) j;

				weight = (*__filterf)(weight / fscale) / fscale;
				if (j < 0)
					n = -j;
				else if (j >= sd)
					n = (sd - j) + sd - 1;
				else
					n = j;
				k = cl[i].n++;
				cl[i].p[k].pixel = n * src->samplesPerPixel;
				cl[i].p[k].weight = weight;
		}	}	}
	else
		{
		for(i = 0; i < ls; ++i)
			{
			double center = (double) i / scale;
			double left = ceil(center - __fwidth);
			double right = floor(center + __fwidth);

			cl[i].n = 0;
			cl[i].p = (Contrib *)calloc((int) (__fwidth * 2 + 1), sizeof(Contrib));

			for(j = left; j <= right; ++j)
				{
				double weight = center - (double) j;

				weight = (*__filterf)(weight);
				if (j < 0)
					n = -j;
				else if (j >= sd)
					n = (sd - j) + sd - 1;
				else
					n = j;
				k = cl[i].n++;
				cl[i].p[k].pixel = n * src->samplesPerPixel;
				cl[i].p[k].weight = weight;
		}	}	}

	return cl;
}

CGImageRef
_CGZoomFilter( CGImageRef src, unsigned w, unsigned h )
{    
	Clist *ctrb;								// array of contribution lists
	int i, j, k;
	int bpp = src->samplesPerPixel * 8;
    double xscale = (double)w / (double)src->width;		// zoom scale factors
    double yscale = (double)h / (double)src->height;
	unsigned char *raster;
	CGImageRef dst, tmp;

	if (!(dst = CGImageCreate( w, h, 8, bpp, 0, NULL, 0, NULL, NULL, 0, 0)))
		return NULL;
	if (!(ctrb = _ContributionsList( dst, w, src->width, xscale )))
		return NULL;
	if (!(tmp = CGImageCreate( w, src->height, 8, bpp, 0, NULL, 0, NULL, NULL, 0, 0)))
		return NULL;

	raster = calloc(src->width+1, src->samplesPerPixel);
	for(k = 0; k < tmp->height; ++k)
		{
		unsigned char *p = tmp->idata + k * tmp->bytesPerRow;

		if (k < src->height)
			memcpy(raster, src->idata + (k * src->bytesPerRow), src->bytesPerRow);

		for(i = 0; i < tmp->width; ++i)
			{
			Contrib *pp = ctrb[i].p;
			double weights[4] = {0};
			int z;

			for(j = 0; j < ctrb[i].n; ++j)
				for(z = 0; z < tmp->samplesPerPixel; ++z)
					weights[z] += raster[pp[j].pixel + z] * pp[j].weight;

			for(z = 0; z < tmp->samplesPerPixel; ++z, p++)
				*p = CLAMP(weights[z], 0, 255);			// put pixel in tmp
			}
		}
	free(raster);

    for(i = 0; i < dst->width; ++i)			// free the memory allocated for
		free(ctrb[i].p);					// horizontal filter weights
    free(ctrb);

	ctrb = _ContributionsList( dst, dst->height, tmp->height, yscale );
	raster = calloc(tmp->height, tmp->samplesPerPixel);

	for (k = 0; k < w; ++k)	 				// apply filter to zoom vertically
		{									// from tmp to dst
		unsigned char *d = raster;
		unsigned char *p = tmp->idata + k * tmp->samplesPerPixel;
		int z;
											// get_column(raster, tmp, k);
		if(k < tmp->width)					// copy a column into a row
			for(i = tmp->height; i-- > 0; p += tmp->bytesPerRow)
				for(z = 0; z < tmp->samplesPerPixel; ++z)
					*d++ = *(p+z);

		for (i = 0; i < h; ++i)
			{
			Contrib *pp = ctrb[i].p;
			double weights[4] = {0};

			p = dst->idata + i * dst->bytesPerRow + (k * dst->samplesPerPixel);

			for (j = 0; j < ctrb[i].n; ++j)
				for(z = 0; z < dst->samplesPerPixel; ++z)
					weights[z] += raster[pp[j].pixel + z] * pp[j].weight;

			for(z = 0; z < dst->samplesPerPixel; ++z, p++)
				*p = CLAMP(weights[z], 0, 255);			// put pixel in dst
			}
		}
	free(raster);

    for (i = 0; i < dst->height; ++i)
		free(ctrb[i].p);	// free memory allocated for vertical filter weights
    free(ctrb);
	CGImageRelease(tmp);

    return dst;
}
