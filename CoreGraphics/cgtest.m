#include <AppKit/AppKit.h>
#include <CoreGraphics/CoreGraphics.h>


extern CGFloat *_CGMakeConvolutionKernel(CGFloat *kernel, unsigned n, CGFloat s);


void
path_test0()
{
	CGPoint poly[] = {{1,1},{9,1},{9,9},{3,9},{3,5},{7,5},{7,3},{5,3},{5,12},{1,12}};
	int i, count = sizeof(poly) / sizeof(CGPoint);

	CGMutablePathRef p1 = CGPathCreateMutable();
	CGRect br;

	CGPathMoveToPoint(p1, NULL, poly[0].x, poly[0].y);
	for (i = 1; i < count; i++)
		CGPathAddLineToPoint(p1, NULL, poly[i].x, poly[i].y);
	CGPathCloseSubpath(p1);

	printf("Self-intersecting polygon tests\n");
	br = CGPathGetPathBoundingBox(p1);
	printf("polygon bounds %f %f %f %f\n",  br.origin.x,   br.origin.y,
											br.size.width, br.size.height);
	if (CGPathContainsPoint(p1, NULL, (CGPoint){2,2}, YES))
		printf("CGPathContainsPoint {2,2} EO rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){4,7}, YES))
		printf("FAIL:  CGPathContainsPoint {4,7} EO rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){5,4}, YES))
		printf("CGPathContainsPoint {5,4} EO rule\n");
	else
		printf("FAIL:  CGPathContainsPoint {5,4} is outside EO rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){6,4}, YES))
		printf("FAIL:  CGPathContainsPoint {6,4} EO rule\n");

	if (CGPathContainsPoint(p1, NULL, (CGPoint){2,2}, NO))
		printf("CGPathContainsPoint {2,2} WN rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){4,7}, NO))
		printf("CGPathContainsPoint {4,7} WN rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){5,4}, NO))
		printf("CGPathContainsPoint {5,4} WN rule\n");
	else
		printf("FAIL:  CGPathContainsPoint {5,4} is outside WN rule\n");
	if (CGPathContainsPoint(p1, NULL, (CGPoint){6,4}, NO))
		printf("FAIL:  CGPathContainsPoint {6,4} WN rule\n");
}

void
path_test1()
{
	CGPoint poly[] = {{1,1},{9,1},{9,9},{3,9},{3,5},{7,5},{7,3},{5,3},{5,12},{1,12}};
	int i, count = sizeof(poly) / sizeof(CGPoint);

	CGMutablePathRef p1 = CGPathCreateMutable();
	CGPathRef p0;
	CGRect br;

	printf("Path stroke tests\n");

	CGPathMoveToPoint(p1, NULL, poly[0].x, poly[0].y);
	for (i = 1; i < count; i++)
		CGPathAddLineToPoint(p1, NULL, poly[i].x, poly[i].y);
	CGPathAddCurveToPoint( p1, NULL, 20, 252, 50, 252, 50, 230 );
	CGPathCloseSubpath(p1);

	p0 = CGPathCreateCopyByStrokingPath( p1, NULL, 0,0, 0, 0);
	_CGPathDescription(p0, 4);
	printf("#\n# Path dash tests\n#\n");
	p0 = CGPathCreateCopyByDashingPath( p1, NULL, 3, (CGFloat []){2,3}, 2);
	_CGPathDescription(p0, 4);
}

void
gauss_convolution_kernel_test()
{
	CGFloat kernel[9];
	CGFloat *kp;

	printf("Gaussian 1D convolution kernel tests\n");
	kp = _CGMakeConvolutionKernel (kernel, 5, 1);
	printf("kernel [5pt, 1σ]:  %1.15f  %1.15f  %1.15f\n",
			kp[0], kernel[1], kernel[2]);
	kp = _CGMakeConvolutionKernel (kernel, 7, 1);
	printf("kernel [7pt, 1σ]:  %1.15f  %1.15f  %1.15f  %1.15f\n",
			kp[0], kernel[1], kernel[2], kernel[3]);
	kp = _CGMakeConvolutionKernel (kernel, 7, 10);
	printf("kernel [7pt,10σ]:  %1.15f  %1.15f  %1.15f  %1.15f\n",
			kp[0], kernel[1], kernel[2], kernel[3]);
	if ((kp = _CGMakeConvolutionKernel (kernel, 9, 1)) != NULL)
		printf("FAIL:  _CGBuildConvolutionKernel invalid kernel size is OK ?\n");
}


int
main()
{
	CGMutablePathRef p1, p2;
	
	float f = 0.1f;
	float sum = 0;
	float mul = f * 10;
	NSRect r = {1,2,3,0};

	int i;

	printf("CG pre-flight tests\n");

	for (i = 0; i < 10; ++i)
    	sum += f;

	printf("sum = %1.15f, mul = %1.15f, const = %1.15f\n", sum, mul, 1.0f);
// sum = 1.000000119209290, mul = 1.000000000000000
//         000000119209290e-07F
//        1.00000019209290e-07F

	p1 = CGPathCreateMutable();
	CGPathMoveToPoint(p1, NULL, sum, mul);
	CGPathAddLineToPoint(p1, NULL, mul, sum);

	p2 = CGPathCreateMutable();
	CGPathMoveToPoint(p2, NULL, mul, mul);
	CGPathAddLineToPoint(p2, NULL, mul, mul);

	if (CGPathEqualToPath(p1, p2))
		printf("PASS: paths with machine epsilon error are equal\n");
	else
		printf("FAIL: paths with machine epsilon error are NOT equal !\n");

	if (NSIsEmptyRect(r))
		printf("PASS: rect with width is not empty\n");
	else
		printf("FAIL: rect with width is empty !\n");

	r.size = (NSSize){sum - 1.0f, sum - 1.0f};
	if (NSIsEmptyRect(r))
		printf("PASS: rect with only machine epsilon error is empty\n");
	else
		printf("FAIL: rect with only machine epsilon error is NOT empty !\n");
	
	path_test0();
	gauss_convolution_kernel_test();
	path_test1();

	exit (0);
}
