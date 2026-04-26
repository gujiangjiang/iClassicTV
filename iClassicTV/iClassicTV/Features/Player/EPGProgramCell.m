//
//  EPGProgramCell.m
//  iClassicTV
//
//  Created by gujiangjiang on 26-4-25.
//  Copyright (c) 2026年 gujiangjiang. All rights reserved.
//

#import "EPGProgramCell.h"
#import "UIStyleHelper.h" // [新增] 引入样式管理中心

@interface EPGMarqueeLabel ()
// 记录上一次的尺寸和边界，防止滚动列表时触发 layoutSubviews 意外打断正在播放的动画
@property (nonatomic, assign) CGSize lastTextSize;
@property (nonatomic, assign) CGRect lastBounds;
@end

@implementation EPGMarqueeLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.backgroundColor = [UIColor clearColor];
        self.textLabel = [[UILabel alloc] initWithFrame:self.bounds];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.textLabel.lineBreakMode = NSLineBreakByClipping; // 禁用省略号，依赖容器截断
        [self addSubview:self.textLabel];
    }
    return self;
}

- (void)setText:(NSString *)text {
    if (![_text isEqualToString:text]) {
        _text = text;
        self.textLabel.text = text;
        self.lastTextSize = CGSizeZero; // 迫使重新计算布局和动画
        [self setNeedsLayout];
    }
}

- (void)setFont:(UIFont *)font {
    if (_font != font) {
        _font = font;
        self.textLabel.font = font;
        self.lastTextSize = CGSizeZero; // 迫使重新计算布局和动画
        [self setNeedsLayout];
    }
}

- (void)setTextColor:(UIColor *)textColor {
    _textColor = textColor;
    self.textLabel.textColor = textColor;
}

- (void)setShadowColor:(UIColor *)shadowColor {
    _shadowColor = shadowColor;
    self.textLabel.shadowColor = shadowColor;
}

- (void)setShadowOffset:(CGSize)shadowOffset {
    _shadowOffset = shadowOffset;
    self.textLabel.shadowOffset = shadowOffset;
}

- (void)startAnimation {
    self.lastTextSize = CGSizeZero;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    // 如果还没加载出来视图或者没有文本，直接返回，避免运算错误
    if (self.bounds.size.width == 0 || self.text.length == 0) {
        return;
    }
    
    // 严谨地按照字号计算需要的真实宽度
    CGSize textSize;
    if ([self.text respondsToSelector:@selector(sizeWithAttributes:)]) {
        textSize = [self.text sizeWithAttributes:@{NSFontAttributeName: self.textLabel.font}];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        textSize = [self.text sizeWithFont:self.textLabel.font];
#pragma clang diagnostic pop
    }
    
    CGFloat viewWidth = self.bounds.size.width;
    CGFloat viewHeight = self.bounds.size.height;
    CGFloat finalWidth = MAX(textSize.width + 5.0, viewWidth); // 留点边距防止切掉文字边缘
    
    // 如果内容和容器尺寸都没有变化，则不打断当前正在进行的动画
    if (CGSizeEqualToSize(self.lastTextSize, textSize) && CGRectEqualToRect(self.lastBounds, self.bounds)) {
        return;
    }
    
    self.lastTextSize = textSize;
    self.lastBounds = self.bounds;
    
    [self.textLabel.layer removeAllAnimations];
    self.textLabel.transform = CGAffineTransformIdentity;
    self.textLabel.frame = CGRectMake(0, 0, finalWidth, viewHeight);
    
    if (finalWidth > viewWidth) {
        CGFloat overlap = finalWidth - viewWidth;
        NSTimeInterval duration = overlap * 0.04 + 1.0; // 根据溢出长度计算动画时间，保证匀速线性滚动
        
        // 采用 UIViewAnimationOptionCurveLinear 保证跑马灯平滑
        [UIView animateWithDuration:duration delay:1.5 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse | UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction animations:^{
            self.textLabel.transform = CGAffineTransformMakeTranslation(-overlap, 0);
        } completion:nil];
    }
}
@end

@implementation EPGProgramCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        self.timeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.timeLabel.backgroundColor = [UIColor clearColor];
        [UIStyleHelper applyTextStyleToLabel:self.timeLabel isBold:NO fontSize:12.0]; // [适配]
        self.timeLabel.textColor = [UIColor lightGrayColor];
        [self.contentView addSubview:self.timeLabel];
        
        self.titleMarqueeLabel = [[EPGMarqueeLabel alloc] initWithFrame:CGRectZero];
        // [适配] 由于 EPGMarqueeLabel 不是单纯的 UILabel，我们直接配置其对外暴露的属性
        if ([UIStyleHelper isIOS7OrLater]) {
            self.titleMarqueeLabel.font = [UIFont systemFontOfSize:16.0];
            self.titleMarqueeLabel.shadowColor = nil;
            self.titleMarqueeLabel.shadowOffset = CGSizeZero;
        } else {
            self.titleMarqueeLabel.font = [UIFont boldSystemFontOfSize:16.0];
            self.titleMarqueeLabel.shadowColor = [UIColor blackColor];
            self.titleMarqueeLabel.shadowOffset = CGSizeMake(0, -1);
        }
        self.titleMarqueeLabel.textColor = [UIColor whiteColor];
        [self.contentView addSubview:self.titleMarqueeLabel];
        
        self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.statusLabel.backgroundColor = [UIColor clearColor];
        self.statusLabel.textAlignment = NSTextAlignmentRight;
        [UIStyleHelper applyTextStyleToLabel:self.statusLabel isBold:NO fontSize:12.0]; // [适配]
        self.statusLabel.textColor = [UIColor lightGrayColor];
        [self.contentView addSubview:self.statusLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat height = self.contentView.bounds.size.height;
    
    // 1. 时间固定宽度
    CGFloat timeWidth = 45.0;
    self.timeLabel.frame = CGRectMake(15, 0, timeWidth, height);
    
    // 2. 状态文字自适应宽度（优先保障其完整显示）
    [self.statusLabel sizeToFit];
    CGFloat statusWidth = self.statusLabel.bounds.size.width;
    if (statusWidth < 50) statusWidth = 50; // 保底宽度
    self.statusLabel.frame = CGRectMake(width - statusWidth - 15, 0, statusWidth, height);
    
    // 3. 节目名称使用剩余的弹性空间
    CGFloat titleX = CGRectGetMaxX(self.timeLabel.frame) + 10;
    CGFloat titleWidth = self.statusLabel.frame.origin.x - titleX - 10;
    self.titleMarqueeLabel.frame = CGRectMake(titleX, 0, titleWidth, height);
}

@end