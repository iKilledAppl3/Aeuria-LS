#import "ALSPreferencesHeader.h"

#import "ALSPreferencesManager.h"
#import "PSSpecifier.h"
#import "SBWallpaperController.h"

@interface ALSPreferencesHeader()

@property (nonatomic, strong) NSArray *descriptionLabels;
@property (nonatomic, strong) UIView *descriptionView;
@property (nonatomic, strong) UIView *filledOverlay;
@property (nonatomic, strong) CAShapeLayer *filledOverlayMask;
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UIImage *lockscreenWallpaper;
@property (nonatomic, weak) UINavigationBar *navigationBar;
@property (nonatomic, weak) UITableView *parentTableView;
@property (nonatomic, strong) ALSPreferencesManager *preferencesManager;
@property (nonatomic) BOOL tableViewSearched;
@property (nonatomic, strong) UIImageView *wallpaperView;

@end

@implementation ALSPreferencesHeader

static const CGFloat kCircleInnerRadiusProportion = 0.25;
static const CGFloat kCircleOuterRadiusProportion = 0.3;
static const CGFloat kLSTextScale = 0.70;
static const CGFloat kLSTextShift = 0.95;
static const int kLabelPadding = 6;
static const int kMiddlePadding = 8;

static NSString *kALSPreferencesResourcesPath = @"/Library/PreferenceBundles/AeuriaLSPreferences.bundle/";
static CGFloat _wallpaperViewHeight;

- (id)initWithSpecifier:(PSSpecifier *)specifier {
    return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil specifier:specifier];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ALSPreferencesHeader" specifier:specifier];
    if(self) {
        //add the description view containing credits
        _descriptionLabels = @[[UILabel new], [UILabel new]];
        _descriptionView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 0)];
        NSArray *leadingStrings = @[@"Initial Concept by ", @"Tweak Programmed by "];
        NSArray *names = @[@"Zach Williams (Reddit)", @"Bryce Pauken (Twitter)"];
        CGFloat currentOffset = kLabelPadding;
        for(int i=0;i<_descriptionLabels.count;i++) {
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] init];
            [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[leadingStrings objectAtIndex:i] attributes:@{NSUnderlineStyleAttributeName:@(NSUnderlineStyleNone)}]];
            [attributedString appendAttributedString:[[NSAttributedString alloc] initWithString:[names objectAtIndex:i] attributes:@{NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle)}]];
            
            UILabel *label = [_descriptionLabels objectAtIndex:i];
            [label setAttributedText:attributedString];
            [label setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin];
            [label setBackgroundColor:[UIColor clearColor]];
            [label setFont:[UIFont systemFontOfSize:13]];
            [label setTextColor:[UIColor lightGrayColor]];
            [label setTag:i];
            [label setUserInteractionEnabled:YES];
            [label sizeToFit];
            [label setCenter:CGPointMake(50, currentOffset+label.bounds.size.height/2)];
            [_descriptionView addSubview:label];
            
            UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(descriptionLabelTapped:)];
            [tapGestureRecognizer setNumberOfTapsRequired:1];
            [label addGestureRecognizer:tapGestureRecognizer];
            
            currentOffset += (label.bounds.size.height+kLabelPadding);
        }
        [_descriptionView setFrame:CGRectMake(0, 0, 100, currentOffset-20)];
        [_descriptionView setAutoresizingMask:UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleWidth];
        [_descriptionView setBackgroundColor:[UIColor clearColor]];
        
        //called to initialize _wallpaperViewHeight if we haven't already
        CGFloat preferredHeight = [self preferredHeightForWidth:0];
        
        [_descriptionView setFrame:CGRectMake(0, preferredHeight-_descriptionView.frame.size.height+10, self.bounds.size.width, _descriptionView.frame.size.height)];
        
        //create a container to hold (and clip) our header's subviews
        _headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, _wallpaperViewHeight)];
        [_headerContainer setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_headerContainer setBackgroundColor:[UIColor clearColor]];
        [_headerContainer setClipsToBounds:YES];
        
        //create the wallpaper view
        _wallpaperView = [[UIImageView alloc] initWithFrame:CGRectInset(self.headerContainer.bounds, 0, -50)];
        [_wallpaperView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        [_wallpaperView setContentMode:UIViewContentModeScaleAspectFill];
        [_headerContainer addSubview:_wallpaperView];
        
        //get the user's current lock screen wallpaper
        NSData *lockscreenWallpaperData = [NSData dataWithContentsOfFile:@"/var/mobile/Library/SpringBoard/LockBackground.cpbitmap"];
        if(lockscreenWallpaperData) {
            //freed near-immediately
            CFDataRef lockscreenWallpaperDataRef = CFDataCreate(NULL, lockscreenWallpaperData.bytes, lockscreenWallpaperData.length);
            //this is a declaration for the method used in the following statement, not a call
            CFArrayRef CPBitmapCreateImagesFromData(CFDataRef cpbitmap, void*, int, void*);
            //freed after if statement
            CFArrayRef wallpaperArray = CPBitmapCreateImagesFromData(lockscreenWallpaperDataRef, NULL, 1, NULL);
            CFRelease(lockscreenWallpaperDataRef);
            if(CFArrayGetCount(wallpaperArray) > 0) {
                CGImageRef lockscreenWallpaperRef = (CGImageRef)CFArrayGetValueAtIndex(wallpaperArray, 0);
                _lockscreenWallpaper = [UIImage imageWithCGImage:lockscreenWallpaperRef];
                [_wallpaperView setImage:_lockscreenWallpaper];
            }
            CFRelease(wallpaperArray);
        }
        
        UIView *backgroundColorOverlay = [[UIView alloc] initWithFrame:_headerContainer.bounds];
        [backgroundColorOverlay setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
        [_headerContainer addSubview:backgroundColorOverlay];
        
        //create the filled overlay that shows the title and circle
        _filledOverlay = [[UIView alloc] initWithFrame:self.headerContainer.bounds];
        [_filledOverlay setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        _filledOverlayMask = [[CAShapeLayer alloc] init];
        [_filledOverlayMask setFillColor:[[UIColor blackColor] CGColor]];
        [_filledOverlayMask setFillRule:kCAFillRuleEvenOdd];
        [_filledOverlay.layer setMask:_filledOverlayMask];
        [_headerContainer addSubview:_filledOverlay];
        
        //create views outside of the self.headerContainer to cast a shadow inside
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        CGFloat shadowCastingViewWidth = MAX(screenBounds.size.width, screenBounds.size.height)*2;
        for(int i=0;i<2;i++) {
            UIView *shadowCastingView = [[UIView alloc] initWithFrame:CGRectMake(-20, (i==0?-20:self.headerContainer.bounds.size.height), shadowCastingViewWidth+40, 20)];
            [shadowCastingView setBackgroundColor:[UIColor blackColor]];
            [shadowCastingView.layer setMasksToBounds:NO];
            [shadowCastingView.layer setShadowOffset:CGSizeMake(0, 0)];
            [shadowCastingView.layer setShadowOpacity:0.4];
            [shadowCastingView.layer setShadowRadius:2];
            [_headerContainer addSubview:shadowCastingView];
        }
        
        __weak ALSPreferencesHeader *weakSelf = self;
        _preferencesManager = [[ALSPreferencesManager alloc] init];
        [_preferencesManager setPreferencesChanged:^{
            if([[weakSelf.preferencesManager preferenceForKey:@"shouldColorBackground"] boolValue]) {
                [backgroundColorOverlay setBackgroundColor:[[weakSelf.preferencesManager preferenceForKey:@"backgroundColor"] colorWithAlphaComponent:[[weakSelf.preferencesManager preferenceForKey:@"backgroundColorAlpha"] floatValue]]];
            }
            else {
                [backgroundColorOverlay setBackgroundColor:[UIColor clearColor]];
            }
            
            if(![[weakSelf.preferencesManager preferenceForKey:@"shouldBlurLockScreen"] boolValue] || ![UIBlurEffect class] || ![UIVisualEffectView class]) {
                [weakSelf.filledOverlay setBackgroundColor:[[weakSelf.preferencesManager preferenceForKey:@"lockScreenColor"] colorWithAlphaComponent:[[weakSelf.preferencesManager preferenceForKey:@"lockScreenColorAlpha"] floatValue]]];
            }
            else {
                [weakSelf.filledOverlay setBackgroundColor:[UIColor clearColor]];
                [[weakSelf.filledOverlay subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
                int lockScreenBlurType = [[weakSelf.preferencesManager preferenceForKey:@"lockScreenBlurType"] intValue];
                UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:(lockScreenBlurType==0?UIBlurEffectStyleLight:(lockScreenBlurType==1?UIBlurEffectStyleExtraLight:UIBlurEffectStyleDark))];
                UIVisualEffectView *visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
                [visualEffectView setAutoresizingMask:UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth];
                [visualEffectView setFrame:weakSelf.filledOverlay.bounds];
                [weakSelf.filledOverlay addSubview:visualEffectView];
            }
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _preferencesManager.preferencesChanged();
        });
        
        [self setBackgroundColor:[UIColor clearColor]];
        [self updateFilledOverlay];
        [self addSubview:_headerContainer];
        [self addSubview:_descriptionView];
    }
    
    return self;
}

- (void)dealloc {
    [self.parentTableView removeObserver:self forKeyPath:@"contentOffset"];
}

- (void)descriptionLabelTapped:(UITapGestureRecognizer *)tapRecognizer {
    if(tapRecognizer.view.tag==0) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.reddit.com/user/icominblob"]];
    }
    else {
        if([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://user?screen_name=brycepauken"]];
        }
        else {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/brycepauken"]];
        }
    }
}

/*
 We override hitTest:withEvent: to allow for tapping labels outisde of their view
 (plus adding a bit of padding around the outside while we're at it)
 */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    for(UILabel *label in self.descriptionLabels) {
        if(CGRectContainsPoint(CGRectInset([self convertRect:label.frame fromView:label.superview], -kLabelPadding/2, -kLabelPadding/2), point)) {
            return label;
        }
    }
    return [super hitTest:point withEvent:event];
}

- (void)layoutSubviews {
    CGSize filledOverlaySize = self.filledOverlay.bounds.size;
    [super layoutSubviews];
    
    UIView *currentView = self.superview;
    while(!self.navigationBar && currentView) {
        for(UIView *subview in currentView.subviews) {
            if([subview isKindOfClass:[UINavigationBar class]] && !subview.hidden) {
                self.navigationBar = (UINavigationBar *)subview;
                break;
            }
        }
        currentView = currentView.superview;
    }
    
    if(!self.tableViewSearched && self.superview) {
        //find nearest parent tableview
        UIView *currentView = self;
        while(currentView && ![currentView isKindOfClass:[UITableView class]]) {
            currentView = currentView.superview;
        }
        if(currentView) {
            self.parentTableView = (UITableView *)currentView;
            [self.parentTableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
        }
        
        self.tableViewSearched = YES;
    }
    
    if(self.navigationBar) {
        CGFloat xOffset = [self.navigationBar convertPoint:CGPointZero fromView:self].x;
        [self.headerContainer setFrame:CGRectMake(-xOffset, self.headerContainer.frame.origin.y, self.navigationBar.frame.size.width, self.headerContainer.frame.size.height)];
        CGFloat wallpaperOffset = 0;
        if(self.parentTableView) {
            wallpaperOffset = self.parentTableView.contentOffset.y/2;
        }
        [self.wallpaperView setCenter:CGPointMake(self.headerContainer.bounds.size.width/2, self.headerContainer.bounds.size.height/2+wallpaperOffset)];
        for(UILabel *label in self.descriptionLabels) {
            [label setCenter:CGPointMake(-xOffset+self.navigationBar.frame.size.width/2, label.center.y)];
        }
    }
    
    //check if wallpaperView size changed
    if(!CGSizeEqualToSize(filledOverlaySize, self.filledOverlay.bounds.size)) {
        [self.filledOverlayMask setFrame:CGRectMake(0, 0, self.self.filledOverlay.bounds.size.width, self.filledOverlay.bounds.size.height)];
        [self updateFilledOverlay];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if([object isKindOfClass:[UITableView class]]) {
        CGPoint contentOffset = [object contentOffset];
        contentOffset.y /= 2;
        [self.wallpaperView setCenter:CGPointMake(self.headerContainer.bounds.size.width/2, self.headerContainer.bounds.size.height/2+contentOffset.y)];
    }
}

+ (CGPathRef)pathForAeuriaText {
    static CGPathRef path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [self pathFromFile:@"AeuriaPath.dat"];
    });
    return path;
}

+ (CGPathRef)pathForLSText {
    static CGPathRef path;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        path = [self pathFromFile:@"LSPath.dat"];
    });
    return path;
}

/*
 Returns a CGPathRef given by an array of types and coordinates stored in the given file.
 */
+ (CGPathRef)pathFromFile:(NSString *)file {
    //not freed; owned by caller
    CGPathRef path;
    //freed at end of method
    CGMutablePathRef mutablePath = CGPathCreateMutable();
    CGFloat s = 1000;
    NSData *LSPathData = [NSData dataWithContentsOfFile:[kALSPreferencesResourcesPath stringByAppendingString:file]];
    NSArray *LSPathInfo;
    if(LSPathData) {
        LSPathInfo = [NSKeyedUnarchiver unarchiveObjectWithData:LSPathData];
    }
    if(LSPathInfo.count) {
        for(int i=0;i<LSPathInfo.count;i++) {
            int numPoints;
            switch ([LSPathInfo[i] intValue]) {
                case kCGPathElementMoveToPoint:
                    numPoints = 1;
                    CGPathMoveToPoint(mutablePath, NULL,
                        [LSPathInfo[i+1] intValue]/s, [LSPathInfo[i+2] intValue]/s
                    );
                    break;
                case kCGPathElementAddLineToPoint:
                    numPoints = 1;
                    CGPathAddLineToPoint(mutablePath, NULL,
                        [LSPathInfo[i+1] intValue]/s, [LSPathInfo[i+2] intValue]/s
                    );
                    break;
                case kCGPathElementAddQuadCurveToPoint:
                    numPoints = 2;
                    CGPathAddQuadCurveToPoint(mutablePath, NULL,
                        [LSPathInfo[i+1] intValue]/s, [LSPathInfo[i+2] intValue]/s,
                        [LSPathInfo[i+3] intValue]/s, [LSPathInfo[i+4] intValue]/s
                    );
                    break;
                case kCGPathElementAddCurveToPoint:
                    numPoints = 3;
                    CGPathAddCurveToPoint(mutablePath, NULL,
                        [LSPathInfo[i+1] intValue]/s, [LSPathInfo[i+2] intValue]/s,
                        [LSPathInfo[i+3] intValue]/s, [LSPathInfo[i+4] intValue]/s,
                        [LSPathInfo[i+5] intValue]/s, [LSPathInfo[i+6] intValue]/s
                    );
                    break;
                case kCGPathElementCloseSubpath:
                    numPoints = 0;
                    CGPathCloseSubpath(mutablePath);
                    break;
                default:
                    numPoints = 0;
                    break;
            }
            i += numPoints*2;
        }
        path = CGPathCreateCopy(mutablePath);
    }
    else {
        path = CGPathCreateWithRect(CGRectMake(0, 0, 0, 0), NULL);
    }
    CGPathRelease(mutablePath);
    return path;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)arg1 {
    static CGFloat preferredHeight;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        _wallpaperViewHeight = ceilf(sqrtf(MIN(screenBounds.size.width, screenBounds.size.height)*30));
        
        preferredHeight = _wallpaperViewHeight+self.descriptionView.bounds.size.height;
    });
    return preferredHeight;
}

- (void)updateFilledOverlay {
    //create the beginning of our mask
    UIBezierPath *mask = [UIBezierPath bezierPath];
    
    //get our large text paths, which we'll scale down
    CGPathRef aeuriaPath = [[self class] pathForAeuriaText];
    CGSize aeuriaPathSize = CGPathGetPathBoundingBox(aeuriaPath).size;
    CGPathRef lsPath = [[self class] pathForLSText];
    CGSize lsPathSize = CGPathGetPathBoundingBox(lsPath).size;
    
    //find inner and outer circle radius for our current height
    CGFloat innerCircleRadius = self.filledOverlay.bounds.size.height*kCircleInnerRadiusProportion;
    CGFloat outerCircleRadius = self.filledOverlay.bounds.size.height*kCircleOuterRadiusProportion;
    
    //scale the LS path to fit within the inner circle radius
    CGFloat lsHeight = innerCircleRadius*lsPathSize.height/sqrt(lsPathSize.width/2*lsPathSize.width/2+lsPathSize.height/2*lsPathSize.height/2);
    CGFloat lsScale = (lsHeight/lsPathSize.height)*kLSTextScale;
    
    //scale the Aeuria path to the same height as the LS path
    CGFloat aeuriaScale = lsHeight/aeuriaPathSize.height;
    CGFloat aeuriaWidth = (aeuriaPathSize.width*aeuriaScale);
    
    //find the horizontal offset of the group (Aeuria text, then middle padding, then circle)
    CGFloat horizontalOffset = ((self.filledOverlay.bounds.size.width-aeuriaWidth-kMiddlePadding)/2-outerCircleRadius);
    
    //transform and append the LS path
    CGAffineTransform lsTransform = CGAffineTransformMakeScale(lsScale, lsScale);
    lsTransform = CGAffineTransformTranslate(lsTransform, (horizontalOffset+aeuriaWidth+kMiddlePadding+outerCircleRadius-(lsPathSize.width*lsScale)*kLSTextShift/2)/lsScale, ((self.filledOverlay.bounds.size.height-(lsPathSize.height*lsScale))/2)/lsScale);
    CGPathRef scaledLSPath = CGPathCreateCopyByTransformingPath(lsPath, &lsTransform);
    [mask appendPath:[UIBezierPath bezierPathWithCGPath:scaledLSPath]];
    CGPathRelease(scaledLSPath);
    
    //transform and append the Aeuria path
    CGAffineTransform aeuriaTransform = CGAffineTransformMakeScale(aeuriaScale, aeuriaScale);
    //aeuriaTransform = CGAffineTransformTranslate(aeuriaTransform, horizontalOffset/aeuriaScale, ((self.filledOverlay.bounds.size.height+(lsPathSize.height*lsScale))/2-(aeuriaPathSize.height*aeuriaScale))/aeuriaScale);
    aeuriaTransform = CGAffineTransformTranslate(aeuriaTransform, horizontalOffset/aeuriaScale, ((self.filledOverlay.bounds.size.height-(aeuriaPathSize.height*aeuriaScale))/2)/aeuriaScale);
    CGPathRef scaledAeuriaPath = CGPathCreateCopyByTransformingPath(aeuriaPath, &aeuriaTransform);
    [mask appendPath:[UIBezierPath bezierPathWithCGPath:scaledAeuriaPath]];
    CGPathRelease(scaledAeuriaPath);
    
    //add circle to mask
    [mask appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(horizontalOffset+aeuriaWidth+kMiddlePadding, self.filledOverlay.bounds.size.height/2-outerCircleRadius, outerCircleRadius*2, outerCircleRadius*2) byRoundingCorners:UIRectCornerAllCorners cornerRadii:CGSizeMake(outerCircleRadius, outerCircleRadius)]];
    
    [self.filledOverlayMask setPath:mask.CGPath];
}

@end