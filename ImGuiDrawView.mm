// ImGuiDrawView.mm
// ROSI AOV — layout & proportions tuned to match reference screenshot.
// Preserves all controls, logic, switches, sliders, replay panel, toast, and settings persistence.
// Floating "Tự vào trận" button removed.

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

static NSString * const ZSMPreferencesKey = @"com.ngtheanh.zsm.menu.preferences";

static UIColor *ZSMColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a];
}

static UIFont *ZSMFontWithNameOrFallback(NSString *fontName, CGFloat size, UIFontWeight weight) {
    if (fontName.length > 0) {
        UIFont *font = [UIFont fontWithName:fontName size:size];
        if (font) return font;
    }
    return [UIFont systemFontOfSize:size weight:weight];
}

#pragma mark - ZSMMenuView

@interface ZSMMenuView : UIView
@property (nonatomic, strong) UIView *windowView;
@property (nonatomic, strong) UIView *tabBarView;
@property (nonatomic, strong) UIView *tabIndicator;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *toastView;
@property (nonatomic, strong) UILabel *toastTitle;
@property (nonatomic, strong) UILabel *toastMessage;
@property (nonatomic, strong) UIView *replayView;
@property (nonatomic, strong) UILabel *replaySpeedLabel;
@property (nonatomic, strong) UIButton *reopenButton;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *settings;
@property (nonatomic, strong) NSMutableArray<UIButton *> *tabButtons;
@property (nonatomic, strong) NSMutableArray<UIView *> *tabPages;
@property (nonatomic, strong) NSMutableDictionary<NSString *, UISlider *> *sliders;
@property (nonatomic, copy) NSString *faFontName;
@property (nonatomic, copy) NSString *fireFontName;
@property (nonatomic) NSInteger selectedTab;
@property (nonatomic) CGFloat replaySpeed;
@property (nonatomic) BOOL transparentMode;
@property (nonatomic) BOOL screenCaptureMode;
@property (nonatomic) BOOL isSyncingAutoJoin;
@end

@implementation ZSMMenuView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = UIColor.clearColor;
    self.settings = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:ZSMPreferencesKey] mutableCopy];
    if (!self.settings) self.settings = [NSMutableDictionary dictionary];
    self.tabButtons = [NSMutableArray array];
    self.tabPages = [NSMutableArray array];
    self.sliders = [NSMutableDictionary dictionary];
    self.replaySpeed = 0.9;

    self.faFontName = nil;
    self.fireFontName = nil;

    [self buildInterface];
    [self applyDefaultSettingsIfNeeded];
    [self registerOrientationObserver];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
}

- (void)registerOrientationObserver {
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDeviceOrientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)handleDeviceOrientationChanged:(NSNotification *)note {
    (void)note;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
        [self clampFloatingViews];
        [self bringSubviewToFront:self.reopenButton];
        if (self.windowView.hidden) {
            self.reopenButton.hidden = NO;
        }
    });
}

#pragma mark - Layout

- (void)buildInterface {
    self.windowView = [[UIView alloc] initWithFrame:CGRectZero];
    self.windowView.backgroundColor = ZSMColor(255, 255, 255, 0.98);
    self.windowView.layer.cornerRadius = 20.0;
    self.windowView.layer.borderWidth = 1.25;
    self.windowView.layer.borderColor = ZSMColor(30, 158, 255, 0.85).CGColor;
    self.windowView.layer.shadowColor = ZSMColor(30, 100, 255, 1.0).CGColor;
    self.windowView.layer.shadowOpacity = 0.14;
    self.windowView.layer.shadowRadius = 18.0;
    self.windowView.layer.shadowOffset = CGSizeMake(0, 6);
    self.windowView.clipsToBounds = YES;
    [self addSubview:self.windowView];

    UIView *headerRow = [[UIView alloc] initWithFrame:CGRectZero];
    headerRow.backgroundColor = ZSMColor(251, 253, 255, 1.0);
    headerRow.tag = 902;
    [self.windowView addSubview:headerRow];

    UIView *brandBox = [[UIView alloc] initWithFrame:CGRectZero];
    brandBox.backgroundColor = UIColor.whiteColor;
    brandBox.layer.cornerRadius = 11.0;
    brandBox.layer.borderWidth = 1.25;
    brandBox.layer.borderColor = ZSMColor(214, 232, 252, 1.0).CGColor;
    brandBox.tag = 910;
    [headerRow addSubview:brandBox];

    UILabel *brandLbl = [[UILabel alloc] initWithFrame:CGRectZero];
    brandLbl.text = @"ROSI AOV";
    brandLbl.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    brandLbl.textColor = ZSMColor(34, 42, 58, 1.0);
    brandLbl.textAlignment = NSTextAlignmentCenter;
    brandLbl.tag = 903;
    [brandBox addSubview:brandLbl];

    self.tabBarView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tabBarView.backgroundColor = ZSMColor(251, 253, 255, 1.0);
    self.tabBarView.tag = 920;
    [headerRow addSubview:self.tabBarView];

    self.tabIndicator = [[UIView alloc] initWithFrame:CGRectZero];
    self.tabIndicator.backgroundColor = ZSMColor(30, 158, 255, 1.0);
    self.tabIndicator.layer.cornerRadius = 1.5;
    [self.tabBarView addSubview:self.tabIndicator];

    NSArray *tabIcons  = @[@"⌂",    @"◎",    @"◇",    @"▦"];
    NSArray *tabLabels = @[@"HOME", @"AUTO", @"SKIN", @"MORE"];
    for (NSInteger i = 0; i < 4; i++) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.tag = i;
        button.titleLabel.numberOfLines = 2;
        button.titleLabel.textAlignment = NSTextAlignmentCenter;
        button.titleLabel.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightMedium];
        [button setTitle:[NSString stringWithFormat:@"%@\n%@", tabIcons[i], tabLabels[i]]
                forState:UIControlStateNormal];
        [button setTitleColor:ZSMColor(138, 150, 170, 1.0) forState:UIControlStateNormal];
        [button setTitleColor:ZSMColor(30, 158, 255, 1.0)  forState:UIControlStateSelected];
        [button addTarget:self action:@selector(selectTab:) forControlEvents:UIControlEventTouchUpInside];
        [self.tabBarView addSubview:button];
        [self.tabButtons addObject:button];
    }

    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"✕" forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightRegular];
    [close setTitleColor:ZSMColor(145, 155, 172, 1.0) forState:UIControlStateNormal];
    close.tag = 904;
    [close addTarget:self action:@selector(closeMenu) forControlEvents:UIControlEventTouchUpInside];
    [headerRow addSubview:close];

    UIView *headerDivider = [[UIView alloc] initWithFrame:CGRectZero];
    headerDivider.backgroundColor = ZSMColor(232, 242, 255, 1.0);
    headerDivider.tag = 905;
    [self.windowView addSubview:headerDivider];

    self.contentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.contentView.backgroundColor = ZSMColor(255, 255, 255, 1.0);
    [self.windowView addSubview:self.contentView];

    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.showsVerticalScrollIndicator = YES;
    [self.contentView addSubview:self.scrollView];

    [self applyLayout];

    CGFloat initialPageWidth = self.scrollView.bounds.size.width;
    CGFloat initialPageHeight = MAX(270.0, [self pageHeightForWidth:initialPageWidth]);
    for (NSInteger i = 0; i < 4; i++) {
        UIView *page = [[UIView alloc] initWithFrame:CGRectMake(0, 0, initialPageWidth, initialPageHeight)];
        page.hidden = (i != 0);
        [self.scrollView addSubview:page];
        [self.tabPages addObject:page];
    }

    [self buildMainPage:self.tabPages[0]];
    [self buildAutoPage:self.tabPages[1]];
    [self buildSkinPage:self.tabPages[2]];
    [self buildMorePage:self.tabPages[3]];

    self.reopenButton = [self button:@"ROSI AOV" action:@selector(openMenu)];
    self.reopenButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.reopenButton.backgroundColor = ZSMColor(30, 158, 255, 1);
    [self.reopenButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.reopenButton.layer.cornerRadius = 10;
    self.reopenButton.frame = CGRectMake(self.bounds.size.width - 170, self.bounds.size.height - 58, 155, 40);
    self.reopenButton.hidden = YES;
    [self addSubview:self.reopenButton];

    [self buildReplayPanel];
    [self selectTabIndex:0];
    [self applyLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self applyLayout];
    [self clampFloatingViews];
}

- (void)applyLayout {
    CGFloat maxW = MIN(618.0, self.bounds.size.width - 28.0);
    CGFloat minW = MIN(340.0, self.bounds.size.width - 16.0);
    CGFloat width = MAX(minW, maxW);

    CGFloat targetH = width * (468.0 / 618.0);
    CGFloat maxH = MIN(475.0, self.bounds.size.height - 32.0);
    CGFloat minH = MIN(290.0, self.bounds.size.height - 16.0);
    CGFloat height = MAX(minH, MIN(targetH, maxH));

    CGFloat x = (self.bounds.size.width - width) * 0.5;
    CGFloat y = (self.bounds.size.height - height) * 0.5;
    self.windowView.frame = CGRectMake(x, y, width, height);

    CGFloat hdrH = 62.0;
    UIView *headerRow = [self.windowView viewWithTag:902];
    headerRow.frame = CGRectMake(0, 0, width, hdrH);

    CGFloat brandW = (width < 430.0) ? 98.0 : 124.0;
    CGFloat brandH = 40.0;
    UIView *brandBox = [headerRow viewWithTag:910];
    brandBox.frame = CGRectMake(16.0, (hdrH - brandH) * 0.5, brandW, brandH);
    UILabel *brandLbl = (UILabel *)[brandBox viewWithTag:903];
    brandLbl.frame = brandBox.bounds;

    UIButton *close = (UIButton *)[headerRow viewWithTag:904];
    close.frame = CGRectMake(width - 44.0, (hdrH - 30.0) * 0.5, 30.0, 30.0);

    CGFloat tabBarX = CGRectGetMaxX(brandBox.frame) + 18.0;
    CGFloat tabBarRight = close.frame.origin.x - 10.0;
    CGFloat tabBarW = MAX(140.0, tabBarRight - tabBarX);
    self.tabBarView.frame = CGRectMake(tabBarX, 0, tabBarW, hdrH);

    NSInteger tabCount = MAX(1, (NSInteger)self.tabButtons.count);
    CGFloat slotW = tabBarW / tabCount;
    CGFloat btnW = MIN(76.0, slotW);
    for (NSInteger i = 0; i < tabCount; i++) {
        CGFloat slotCenter = i * slotW + slotW * 0.5;
        self.tabButtons[i].frame = CGRectMake(slotCenter - btnW * 0.5, 0, btnW, hdrH);
    }
    [self updateTabIndicator];

    UIView *headerDivider = [self.windowView viewWithTag:905];
    headerDivider.frame = CGRectMake(0, hdrH, width, 1.0);

    self.contentView.frame = CGRectMake(0, hdrH + 1.0, width, height - hdrH - 1.0);
    self.scrollView.frame = CGRectMake(0, 0, self.contentView.bounds.size.width, self.contentView.bounds.size.height);

    CGFloat pageWidth = self.scrollView.bounds.size.width;
    CGFloat pageHeight = MAX(260.0, [self pageHeightForWidth:pageWidth]);
    for (UIView *page in self.tabPages) {
        page.frame = CGRectMake(0, 0, pageWidth, pageHeight);
    }
    self.scrollView.contentSize = CGSizeMake(pageWidth, pageHeight);
}

- (void)updateTabIndicator {
    if (self.selectedTab < (NSInteger)self.tabButtons.count) {
        UIButton *btn = self.tabButtons[self.selectedTab];
        CGFloat iw = MIN(52.0, btn.bounds.size.width - 14.0);
        CGFloat ix = btn.frame.origin.x + (btn.bounds.size.width - iw) * 0.5;
        self.tabIndicator.frame = CGRectMake(ix, self.tabBarView.bounds.size.height - 3.0, iw, 3.0);
    }
}

- (void)clampFloatingViews {
    UIEdgeInsets safe = self.safeAreaInsets;
    CGFloat minX = safe.left + 8.0;
    CGFloat maxX = self.bounds.size.width - safe.right - 8.0;
    CGFloat minY = safe.top + 8.0;
    CGFloat maxY = self.bounds.size.height - safe.bottom - 8.0;

    if (self.reopenButton) {
        CGSize s = self.reopenButton.bounds.size;
        if (CGSizeEqualToSize(s, CGSizeZero)) s = CGSizeMake(155, 40);
        CGFloat rx = MIN(MAX(self.reopenButton.frame.origin.x, minX), MAX(minX, maxX - s.width));
        CGFloat ry = MIN(MAX(self.reopenButton.frame.origin.y, minY), MAX(minY, maxY - s.height));
        self.reopenButton.frame = CGRectMake(rx, ry, s.width, s.height);
    }

    if (self.replayView && !self.replayView.hidden) {
        CGSize s = self.replayView.bounds.size;
        CGFloat px = MIN(MAX(self.replayView.frame.origin.x, minX), MAX(minX, maxX - s.width));
        CGFloat py = MIN(MAX(self.replayView.frame.origin.y, minY), MAX(minY, maxY - s.height));
        self.replayView.frame = CGRectMake(px, py, s.width, s.height);
    }
}

- (CGFloat)pageHeightForWidth:(CGFloat)width {
    (void)width;
    return 430.0;
}

#pragma mark - Components

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.textColor = ZSMColor(42, 49, 61, 1.0);
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.numberOfLines = 0;
    return label;
}

- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:ZSMColor(30,40,60,1) forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    button.backgroundColor = ZSMColor(240, 247, 255, 1);
    button.layer.borderWidth = 1;
    button.layer.borderColor = ZSMColor(190, 220, 255, 0.9).CGColor;
    button.layer.cornerRadius = 8;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (UIView *)panel:(NSString *)title inView:(UIView *)parent y:(CGFloat)y height:(CGFloat)height {
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(14, y, parent.bounds.size.width-28, height)];
    panel.backgroundColor = ZSMColor(240, 247, 255, 1.0);
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = ZSMColor(190, 220, 255, 0.9).CGColor;
    panel.layer.cornerRadius = 10;
    UILabel *heading = [self label:title size:11 weight:UIFontWeightBold];
    heading.backgroundColor = ZSMColor(240, 247, 255, 1);
    heading.textColor = ZSMColor(100, 130, 170, 1);
    heading.frame = CGRectMake(10, -7, panel.bounds.size.width-20, 16);
    [panel addSubview:heading];
    [parent addSubview:panel];
    return panel;
}

- (UISwitch *)addSwitch:(NSString *)title key:(NSString *)key toView:(UIView *)parent frame:(CGRect)frame defaultValue:(BOOL)value {
    CGFloat switchScale = 0.78;
    CGFloat switchW = 51.0 * switchScale;
    CGFloat gap = 8.0;
    CGFloat labelW = MAX(60.0, frame.size.width - switchW - gap);

    UILabel *label = [self label:title size:12.0 weight:UIFontWeightRegular];
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.frame = CGRectMake(frame.origin.x,
                             frame.origin.y + (frame.size.height - 22.0) * 0.5,
                             labelW,
                             22.0);
    [parent addSubview:label];

    UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectMake(0, 0, 51.0, 31.0)];
    toggle.transform = CGAffineTransformMakeScale(switchScale, switchScale);
    toggle.on = self.settings[key] ? [self.settings[key] boolValue] : value;
    toggle.onTintColor = ZSMColor(82, 102, 122, 1.0);
    toggle.thumbTintColor = UIColor.whiteColor;
    toggle.accessibilityIdentifier = key;
    toggle.center = CGPointMake(frame.origin.x + frame.size.width - switchW * 0.5,
                              frame.origin.y + frame.size.height * 0.5);
    [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [parent addSubview:toggle];
    return toggle;
}

- (void)addChoiceGroup:(NSString *)title key:(NSString *)key options:(NSArray<NSString *> *)options toView:(UIView *)parent y:(CGFloat)y {
    UIView *panel = [self panel:title inView:parent y:y height:58];
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:options];
    seg.frame = CGRectMake(8, 19, panel.bounds.size.width-16, 30);
    seg.selectedSegmentIndex = [self.settings[key] respondsToSelector:@selector(integerValue)] ? [self.settings[key] integerValue] : 0;
    seg.selectedSegmentTintColor = ZSMColor(30, 158, 255, 1);
    seg.backgroundColor = ZSMColor(220, 236, 255, 1);
    seg.tag = 700 + (NSInteger)[key hash] % 1000;
    seg.accessibilityIdentifier = key;
    [seg addTarget:self action:@selector(choiceChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:seg];
}

- (void)addSlider:(NSString *)title key:(NSString *)key min:(float)minimum max:(float)maximum value:(float)value toView:(UIView *)parent y:(CGFloat)y {
    UIView *panel = [self panel:title inView:parent y:y height:58];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(10, 19, panel.bounds.size.width-20, 24)];
    slider.minimumValue = minimum;
    slider.maximumValue = maximum;
    slider.value = [self.settings[key] respondsToSelector:@selector(floatValue)] ? [self.settings[key] floatValue] : value;
    slider.accessibilityIdentifier = key;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [panel addSubview:slider];
    UILabel *valueLabel = [self label:[NSString stringWithFormat:@"%.1f", slider.value] size:10 weight:UIFontWeightSemibold];
    valueLabel.textAlignment = NSTextAlignmentRight;
    valueLabel.frame = CGRectMake(10, 39, panel.bounds.size.width-20, 14);
    valueLabel.tag = 800;
    [panel addSubview:valueLabel];
    self.sliders[key] = slider;
}

#pragma mark - Pages

- (void)buildMainPage:(UIView *)page {
    page.backgroundColor = UIColor.clearColor;
    NSArray *names = @[@"Teleprot Auto", @"Teleport Button", @"Mini Boot",
                       @"Thoát Nhanh", @"Nitro Demo", @"Nitro Speed Demo",
                       @"ECU 3 lượt", @"Acceleration Demo", @"Fake Tên"];
    NSArray *keys = @[@"chkUnlockSkin", @"chkFakeName", @"chkDrawLine",
                      @"chkBlockReport", @"chkDrawIcon", @"chkDrawBoder",
                      @"chkDrawHp", @"chkDrawUtils", @"chkDrawMap"];

    CGFloat pageW = page.bounds.size.width;
    CGFloat leftPad = 18.0;
    CGFloat rightPad = 18.0;
    CGFloat colGap = 14.0;
    CGFloat availW = MAX(270.0, pageW - leftPad - rightPad);
    CGFloat colW = (availW - colGap * 2.0) / 3.0;

    CGFloat topY = 18.0;
    CGFloat rowH = 34.0;
    CGFloat rowGap = 14.0;

    for (NSInteger i = 0; i < (NSInteger)names.count; i++) {
        NSInteger col = i % 3;
        NSInteger row = i / 3;
        CGFloat x = leftPad + col * (colW + colGap);
        CGFloat y = topY + row * (rowH + rowGap);
        [self addSwitch:names[i]
                    key:keys[i]
                 toView:page
                  frame:CGRectMake(x, y, colW, rowH)
           defaultValue:(i == 2)];
    }

    CGFloat gridBottomY = topY + 2 * (rowH + rowGap) + rowH + 14.0;
    [self addSlider:@"Speed Preview (%)" key:@"sldTrungTri" min:1 max:30 value:13.5 toView:page y:gridBottomY];
    [self addSlider:@"Boost Preview (%)" key:@"sldBocPha" min:7 max:20 value:13.9 toView:page y:gridBottomY + 68.0];
}

- (CGFloat)pageColumnWidth {
    return MAX(95.0, (self.scrollView.bounds.size.width - 36.0) / 3.0);
}

- (void)buildAutoPage:(UIView *)page {
    [self addChoiceGroup:@"Auto Match Demo Xếp Hạng" key:@"aimOption"
                 options:@[@"Tốc Độ-Đơn", @"Tốc Độ-Đội", @"Đạo Cụ-Đội"] toView:page y:14];
    [self addChoiceGroup:@"Settings · Hành động" key:@"targetPriority"
                 options:@[@"Auto Match Demo", @"Quẹt Trong Trận", @"Race Demo", @"Auto Mode Demo"] toView:page y:82];
    [self addChoiceGroup:@"Settings · Chế độ" key:@"laserDraw"
                 options:@[@"Auto Match Demo", @"Kí Sinh", @"Chỉnh Replay"] toView:page y:150];
    [self addChoiceGroup:@"Replay Server" key:@"replayServer"
                 options:@[@"VNG", @"QQ"] toView:page y:218];
    [self addSwitch:@"Replay Save Demo" key:@"chkAutoSaveReplay" toView:page frame:CGRectMake(18, 288, 220, 34) defaultValue:NO];

    UIButton *note = [self button:@"Demo interaction note  ▾" action:@selector(toggleReplayNote)];
    note.frame = CGRectMake(14, 330, page.bounds.size.width-28, 30);
    [page addSubview:note];
    UILabel *noteText = [self label:@"Demo note: controls update local UI state only. Settings can be saved, reset, and previewed without connecting to an external app." size:10 weight:UIFontWeightRegular];
    noteText.frame = CGRectMake(18, 364, page.bounds.size.width-36, 48);
    noteText.hidden = YES;
    noteText.tag = 811;
    [page addSubview:noteText];
}

- (void)buildSkinPage:(UIView *)page {
    UIView *panel = [self panel:@"Skin Settings" inView:page y:18 height:120];
    [self addSwitch:@"UnlockXe+Skin" key:@"chkStreamerMode" toView:panel frame:CGRectMake(10, 18, panel.bounds.size.width-20, 30) defaultValue:NO];
    [self addSwitch:@"Mod Skin" key:@"chkCamNghieng" toView:panel frame:CGRectMake(10, 54, panel.bounds.size.width-20, 30) defaultValue:NO];
    [self addSwitch:@"Mod Chỉ Số" key:@"chkLockCam" toView:panel frame:CGRectMake(10, 90, panel.bounds.size.width-20, 30) defaultValue:NO];
}

- (void)buildMorePage:(UIView *)page {
    UIView *panel = [self panel:@"More & UI Demo" inView:page y:18 height:250];
    NSArray *row1 = @[@"Fix login", @"UI Demo", @"Xóa acc cấm"];
    for (NSInteger i=0; i<3; i++) {
        UIButton *b = [self button:row1[i] action:@selector(moreAction:)];
        b.tag = i;
        b.frame = CGRectMake(8+i*(panel.bounds.size.width/3.0), 22, panel.bounds.size.width/3.0-6, 30);
        [panel addSubview:b];
    }
    NSArray *row2 = @[@"Momo", @"Facebook", @"Telegram", @"Screen Capture"];
    for (NSInteger i=0; i<4; i++) {
        UIButton *b = [self button:row2[i] action:@selector(moreAction:)];
        b.tag = 10+i;
        CGFloat w = (panel.bounds.size.width-20)/2;
        b.frame = CGRectMake(8+(i%2)*(w+4), 62+(i/2)*38, w, 30);
        [panel addSubview:b];
    }
    NSArray *row3 = @[@"Lưu Cài Đặt", @"Sử Dụng", @"Đặt Lại"];
    SEL actions[] = {@selector(saveSettings), @selector(applySettings), @selector(resetSettings)};
    for (NSInteger i=0; i<3; i++) {
        UIButton *b = [self button:row3[i] action:actions[i]];
        b.frame = CGRectMake(8+i*(panel.bounds.size.width/3.0), 151, panel.bounds.size.width/3.0-6, 30);
        [panel addSubview:b];
    }
    [self addSlider:@"Fix login" key:@"sldMoreCustom" min:0 max:100 value:50 toView:panel y:188];

    UIView *about = [self panel:@"Giới thiệu" inView:page y:280 height:76];
    UILabel *description = [self label:@"ORBIT UI demonstration. Switches, segmented controls, sliders, and buttons are interactive but only change local demo state." size:10 weight:UIFontWeightRegular];
    description.frame = CGRectMake(10, 16, about.bounds.size.width-20, 52);
    [about addSubview:description];
}

#pragma mark - Replay panel

- (void)buildReplayPanel {
    self.replayView = [[UIView alloc] initWithFrame:CGRectMake(20, 80, 180, 88)];
    self.replayView.backgroundColor = ZSMColor(9,9,9,0.96);
    self.replayView.layer.cornerRadius = 10;
    self.replayView.layer.borderWidth = 1;
    self.replayView.layer.borderColor = ZSMColor(200,200,200,0.6).CGColor;
    self.replayView.hidden = YES;
    [self addSubview:self.replayView];

    UILabel *title = [self label:@"REPLAY · KÉO ĐỂ DI CHUYỂN" size:9 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    title.frame = CGRectMake(4, 6, 172, 18);
    [self.replayView addSubview:title];

    UIButton *minus = [self button:@"−" action:@selector(decreaseReplaySpeed)];
    minus.frame = CGRectMake(12, 34, 40, 40);
    minus.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.replayView addSubview:minus];

    self.replaySpeedLabel = [self label:@"0.9x" size:15 weight:UIFontWeightBold];
    self.replaySpeedLabel.textAlignment = NSTextAlignmentCenter;
    self.replaySpeedLabel.frame = CGRectMake(55, 34, 70, 40);
    [self.replayView addSubview:self.replaySpeedLabel];

    UIButton *plus = [self button:@"+" action:@selector(increaseReplaySpeed)];
    plus.frame = CGRectMake(128, 34, 40, 40);
    plus.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.replayView addSubview:plus];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragReplay:)];
    [self.replayView addGestureRecognizer:pan];
}

#pragma mark - Actions & Sync

- (void)selectTab:(UIButton *)sender { [self selectTabIndex:sender.tag]; }

- (void)selectTabIndex:(NSInteger)index {
    self.selectedTab = MAX(0, MIN(3, index));
    for (NSInteger i = 0; i < (NSInteger)self.tabPages.count; i++) {
        self.tabPages[i].hidden = (i != self.selectedTab);
        UIButton *button = self.tabButtons[i];
        button.selected = (i == self.selectedTab);
        button.backgroundColor = UIColor.clearColor;
        button.layer.borderWidth = 0;
    }
    self.scrollView.contentOffset = CGPointZero;
    [UIView animateWithDuration:0.18 animations:^{ [self updateTabIndicator]; }];
}

- (void)trafficDotTapped:(UIButton *)sender {
    if (sender.tag == 0) [self closeMenu];
    else if (sender.tag == 1) [self toggleTransparency];
}

- (void)closeMenu {
    self.windowView.hidden = YES;
    self.reopenButton.hidden = NO;
    [self clampFloatingViews];
    [self bringSubviewToFront:self.reopenButton];
}

- (void)openMenu {
    self.windowView.hidden = NO;
    self.reopenButton.hidden = YES;
}

- (void)toggleTransparency {
    self.transparentMode = !self.transparentMode;
    self.windowView.backgroundColor = self.transparentMode ? ZSMColor(255,255,255,0.55) : ZSMColor(255,255,255,0.98);
    self.contentView.backgroundColor = self.transparentMode ? ZSMColor(255,255,255,0.55) : ZSMColor(255,255,255,1.0);
    [self showToast:@"UI Demo" message:self.transparentMode ? @"Chế độ Trong suốt" : @"Chế độ Mặc định"];
}

- (void)syncAutoJoinState:(BOOL)enabled
                 animated:(BOOL)animated
                showToast:(BOOL)showToast
     forceChoiceIfEnabled:(BOOL)forceChoiceIfEnabled {
    (void)animated;
    if (self.isSyncingAutoJoin) return;
    self.isSyncingAutoJoin = YES;

    self.settings[@"chkAutoJoinMatch"] = @(enabled);
    if (enabled && forceChoiceIfEnabled) {
        [self setChoice:@"targetPriority" index:0];
    }

    [self persistSettings];
    self.isSyncingAutoJoin = NO;

    if (showToast) {
        [self showToast:@"Auto Match Demo" message:enabled ? @"Demo state ON." : @"Demo state OFF."];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier ?: @"Demo Toggle";
    self.settings[key] = @(sender.isOn);

    if ([key isEqualToString:@"chkFakeName"]) {
        [self showToast:@"Teleport Button Demo" message:sender.isOn ? @"Local demo state: ON" : @"Local demo state: OFF"];
    } else if ([key isEqualToString:@"chkAutoSaveReplay"] && sender.isOn) {
        [self setChoice:@"replayServer" index:0];
        [self showToast:@"Replay Save Demo" message:@"Local demo state: ON (VNG selected)"];
    } else {
        [self showToast:key message:sender.isOn ? @"Local demo state: ON" : @"Local demo state: OFF"];
    }
    [self persistSettings];
}

- (void)choiceChanged:(UISegmentedControl *)sender {
    NSString *key = sender.accessibilityIdentifier ?: @"";
    self.settings[key] = @(sender.selectedSegmentIndex);
    if ([key isEqualToString:@"targetPriority"]) {
        BOOL demoSelected = (sender.selectedSegmentIndex == 0);
        self.settings[@"chkAutoJoinMatch"] = @(demoSelected);
        [self showToast:@"Auto Match Demo" message:demoSelected ? @"Selected (UI only)." : @"Deselected (UI only)."];
        if (sender.selectedSegmentIndex == 3) {
            [self showToast:@"Settings" message:@"Đã chọn Auto Mode Demo (tùy chọn giao diện)."];
        }
    } else if ([key isEqualToString:@"replayServer"] && sender.selectedSegmentIndex == 1) {
        self.settings[@"chkAutoSaveReplay"] = @NO;
        [self setSwitch:@"chkAutoSaveReplay" on:NO];
    } else if ([key isEqualToString:@"laserDraw"]) {
        self.replayView.hidden = (sender.selectedSegmentIndex != 2);
        [self clampFloatingViews];
    }
    [self persistSettings];
}

- (void)setChoice:(NSString *)key index:(NSInteger)index {
    self.settings[key] = @(index);
    for (UIView *page in self.tabPages) {
        for (UIView *v in page.subviews) {
            if ([v isKindOfClass:UIView.class]) {
                for (UIView *child in v.subviews) {
                    if ([child isKindOfClass:UISegmentedControl.class] &&
                        [((UISegmentedControl *)child).accessibilityIdentifier isEqualToString:key]) {
                        ((UISegmentedControl *)child).selectedSegmentIndex = index;
                    }
                }
            }
        }
    }
}

- (void)setSwitch:(NSString *)key on:(BOOL)on {
    self.settings[key] = @(on);
    for (UIView *page in self.tabPages) {
        for (UIView *v in page.subviews) {
            if ([v isKindOfClass:UISwitch.class] &&
                [((UISwitch *)v).accessibilityIdentifier isEqualToString:key]) {
                ((UISwitch *)v).on = on;
            }
            for (UIView *child in v.subviews) {
                if ([child isKindOfClass:UISwitch.class] &&
                    [((UISwitch *)child).accessibilityIdentifier isEqualToString:key]) {
                    ((UISwitch *)child).on = on;
                }
            }
        }
    }
}

- (void)sliderChanged:(UISlider *)sender {
    NSString *key = sender.accessibilityIdentifier ?: @"";
    self.settings[key] = @(sender.value);
    UIView *panel = sender.superview;
    UILabel *value = [panel viewWithTag:800];
    value.text = [key isEqualToString:@"sldMoreCustom"] ? [NSString stringWithFormat:@"%d",(int)roundf(sender.value)]
        : [NSString stringWithFormat:@"%.1f", sender.value];
    [self persistSettings];
}

- (void)toggleReplayNote {
    UIView *note = self.tabPages[1];
    UILabel *text = [note viewWithTag:811];
    text.hidden = !text.hidden;
}

- (void)decreaseReplaySpeed { [self stepReplaySpeed:-0.1]; }
- (void)increaseReplaySpeed { [self stepReplaySpeed:0.1]; }

- (void)stepReplaySpeed:(CGFloat)delta {
    self.replaySpeed = MIN(3.0, MAX(0.1, round((self.replaySpeed+delta)*10.0)/10.0));
    self.replaySpeedLabel.text = [NSString stringWithFormat:@"%.1fx", self.replaySpeed];
}

- (void)dragReplay:(UIPanGestureRecognizer *)gesture {
    CGPoint delta = [gesture translationInView:self];
    self.replayView.center = CGPointMake(self.replayView.center.x+delta.x, self.replayView.center.y+delta.y);
    [gesture setTranslation:CGPointZero inView:self];
    if (gesture.state == UIGestureRecognizerStateEnded || gesture.state == UIGestureRecognizerStateCancelled) {
        [self clampFloatingViews];
    }
}

- (void)moreAction:(UIButton *)sender {
    switch (sender.tag) {
        case 0:
            [self showToast:@"Fix login" message:@"Đây là giao diện mẫu; không thực hiện thay đổi đăng nhập."];
            break;
        case 1: [self toggleTransparency]; break;
        case 2: {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Demo Action?"
                message:@"UI demo only: no files, accounts, or external data are changed."
                preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
            [self presentAlert:alert];
            break;
        }
        case 10: [self showToast:@"Momo" message:@"Demo button pressed (UI only)."] ; break;
        case 11: [self showToast:@"Facebook" message:@"Demo button pressed (UI only)."] ; break;
        case 12: [self showToast:@"Telegram" message:@"Demo button pressed (UI only)."] ; break;
        case 13:
            self.screenCaptureMode = !self.screenCaptureMode;
            [self showToast:@"Screen Capture Mode" message:self.screenCaptureMode ? @"ON" : @"OFF"];
            break;
        default: break;
    }
}

- (void)presentAlert:(UIAlertController *)alert {
    UIViewController *controller = [self nearestViewController];
    if (controller) [controller presentViewController:alert animated:YES completion:nil];
}

- (UIViewController *)nearestViewController {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:UIViewController.class]) return (UIViewController *)responder;
    }
    return nil;
}

- (void)saveSettings {
    [self persistSettings];
    [self showToast:@"Lưu Cài Đặt" message:@"Đã lưu các tùy chọn giao diện."];
}

- (void)applySettings {
    [self persistSettings];
    [self showToast:@"Sử Dụng" message:@"Đã áp dụng các tùy chọn giao diện."];
}

- (void)resetSettings {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:ZSMPreferencesKey];
    self.settings = [NSMutableDictionary dictionary];
    [self setSwitch:@"chkDrawLine" on:YES];
    NSArray *defaults = @[
        @[@"aimOption", @1], @[@"targetPriority", @0],
        @[@"laserDraw", @0], @[@"replayServer", @0]
    ];
    for (NSArray *entry in defaults) [self setChoice:entry[0] index:[entry[1] integerValue]];
    for (NSString *key in @[@"chkUnlockSkin",@"chkFakeName",@"chkBlockReport",@"chkDrawIcon",
                             @"chkDrawBoder",@"chkDrawHp",@"chkDrawUtils",@"chkDrawMap",
                             @"chkAutoSaveReplay",@"chkStreamerMode",@"chkCamNghieng",@"chkLockCam"]) {
        [self setSwitch:key on:NO];
    }
    [self setSlider:@"sldTrungTri" value:13.5];
    [self setSlider:@"sldBocPha" value:13.9];
    [self setSlider:@"sldMoreCustom" value:50];
    self.replaySpeed = 0.9;
    self.replaySpeedLabel.text = @"0.9x";
    self.replayView.hidden = YES;
    self.transparentMode = NO;
    self.windowView.backgroundColor = ZSMColor(255,255,255,0.98);
    self.contentView.backgroundColor = ZSMColor(255,255,255,1.0);
    self.screenCaptureMode = NO;
    self.settings[@"chkAutoJoinMatch"] = @NO;
    [self persistSettings];
    [self showToast:@"Đặt Lại" message:@"Đã khôi phục cài đặt mặc định."];
}

- (void)setSlider:(NSString *)key value:(float)value {
    UISlider *slider = self.sliders[key];
    if (!slider) return;
    slider.value = value;
    [self sliderChanged:slider];
}

- (void)persistSettings {
    [[NSUserDefaults standardUserDefaults] setObject:self.settings forKey:ZSMPreferencesKey];
}

#pragma mark - Toast

- (void)showToast:(NSString *)title message:(NSString *)message {
    [self.toastView removeFromSuperview];
    UIView *toast = [[UIView alloc] initWithFrame:CGRectMake(self.bounds.size.width-230, 70, 215, 62)];
    toast.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    toast.backgroundColor = UIColor.whiteColor;
    toast.layer.cornerRadius = 6;
    toast.layer.shadowColor = UIColor.blackColor.CGColor;
    toast.layer.shadowOpacity = 0.35;
    toast.layer.shadowRadius = 8;
    self.toastView = toast;

    UILabel *heading = [[UILabel alloc] initWithFrame:CGRectMake(12, 7, 190, 18)];
    heading.text = title;
    heading.textColor = UIColor.blackColor;
    heading.font = [UIFont boldSystemFontOfSize:11];
    [toast addSubview:heading];
    self.toastTitle = heading;

    UILabel *body = [[UILabel alloc] initWithFrame:CGRectMake(12, 27, 190, 28)];
    body.text = message;
    body.textColor = ZSMColor(50,50,50,1);
    body.font = [UIFont systemFontOfSize:10];
    body.numberOfLines = 2;
    [toast addSubview:body];
    self.toastMessage = body;

    [self addSubview:toast];
    toast.alpha = 0;
    [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 1; }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.6*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (self.toastView == toast) {
            [UIView animateWithDuration:0.2 animations:^{ toast.alpha = 0; }
                             completion:^(BOOL finished) {
                                 (void)finished;
                                 [toast removeFromSuperview];
                             }];
        }
    });
}

#pragma mark - Defaults

- (void)applyDefaultSettingsIfNeeded {
    if (!self.settings[@"chkDrawLine"]) self.settings[@"chkDrawLine"] = @YES;
    if (!self.settings[@"aimOption"]) self.settings[@"aimOption"] = @1;
    if (!self.settings[@"targetPriority"]) self.settings[@"targetPriority"] = @1;
    if (!self.settings[@"laserDraw"]) self.settings[@"laserDraw"] = @0;
    if (!self.settings[@"replayServer"]) self.settings[@"replayServer"] = @0;
    if (!self.settings[@"chkAutoJoinMatch"]) self.settings[@"chkAutoJoinMatch"] = @NO;
    [self persistSettings];
}

@end

static __weak ZSMMenuView *gZSMMenuView = nil;

#ifdef __cplusplus
extern "C" {
#endif

void ZSMShowMenuInWindow(UIWindow *window) {
    if (!window) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (gZSMMenuView && gZSMMenuView.superview == window) {
            gZSMMenuView.hidden = NO;
            [window bringSubviewToFront:gZSMMenuView];
            return;
        }
        ZSMMenuView *menu = [[ZSMMenuView alloc] initWithFrame:window.bounds];
        menu.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [window addSubview:menu];
        gZSMMenuView = menu;
    });
}

void ZSMHideMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gZSMMenuView.hidden = YES;
    });
}

#ifdef __cplusplus
}
#endif
