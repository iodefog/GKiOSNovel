//
//  GKReadContentController.m
//  GKiOSNovel
//
//  Created by wangws1990 on 2019/6/19.
//  Copyright © 2019 wangws1990. All rights reserved.
//

#import "GKReadContentController.h"
#import "GKReadViewController.h"
#import "GKBookChapterController.h"
#import "GKBookSourceModel.h"
#import "GKBookChapterModel.h"
#import "GKBookContentModel.h"
#import "GKBookReadModel.h"
#import "GKReadTopView.h"
#import "GKReadBottomView.h"
#import "GKReadSetView.h"
#import "GKReadView.h"
#import "GKBookCacheTool.h"
#define gkSetHeight (180 + TAB_BAR_ADDING)

@interface GKReadContentController ()<UIPageViewControllerDelegate,UIPageViewControllerDataSource,GKReadSetDelegate>

@property (strong, nonatomic) UIPageViewController *pageViewController;
@property (strong, nonatomic) UIImageView *mainView;
@property (strong, nonatomic) GKReadTopView *topView;
@property (strong, nonatomic) GKReadBottomView *bottomView;
@property (strong, nonatomic) GKReadSetView *setView;

@property (strong, nonatomic) GKBookDetailModel *model;
@property (strong, nonatomic) GKBookSourceInfo *bookSource;
@property (strong, nonatomic) GKBookChapterInfo *bookChapter;
@property (strong, nonatomic) GKBookContentModel *bookContent;

@property (strong, nonatomic) GKBookReadModel *bookModel;

@property (assign, nonatomic) NSInteger chapter;
@property (assign, nonatomic) NSInteger pageIndex;
@end

@implementation GKReadContentController
+ (instancetype)vcWithBookDetailModel:(GKBookDetailModel *)model{
    GKReadContentController *vc = [[[self class] alloc] init];
    vc.model = model;
    return vc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadUI];
    [self loadData];
}
- (void)loadUI{
    [self.view addSubview:self.mainView];
    [self.mainView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.mainView.superview);
    }];
    self.topView.titleLab.text = self.model.title?:@"";
    self.fd_prefersNavigationBarHidden = YES;
    self.pageViewController = [[UIPageViewController alloc] initWithTransitionStyle:UIPageViewControllerTransitionStyleScroll navigationOrientation:UIPageViewControllerNavigationOrientationHorizontal options:nil];
    self.pageViewController.doubleSided = YES;
    
    
    self.pageViewController.dataSource = self;
    self.pageViewController.delegate = self;
    [self addChildViewController:self.pageViewController];
    [self.view addSubview:self.pageViewController.view];
    
    [self.pageViewController.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.pageViewController.view.superview);
    }];
    
    [self.pageViewController didMoveToParentViewController:self];

    [self performSelector:@selector(tapAction) withObject:nil afterDelay:0.50];
    [self.view addSubview:self.topView];
    [self.topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.equalTo(self.topView.superview);
        make.height.offset(NAVI_BAR_HIGHT);
    }];
    [self.view addSubview:self.bottomView];
    [self.bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.bottomView.superview);
        make.height.offset(TAB_BAR_ADDING + 49);
    }];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.view addSubview:btn];
    [btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.offset(SCALEW(120));
        make.center.equalTo(btn.superview);
    }];
    [btn addTarget:self action:@selector(tapAction) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.setView];
    [self.setView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.setView.superview);
        make.height.offset(gkSetHeight);
        make.bottom.offset(gkSetHeight);
    }];
    self.setView.hidden = YES;
}
- (void)loadData{
    [self readSetView:nil state:0];
    [GKBookReadDataQueue getDataFromDataBase:self.model._id completion:^(GKBookReadModel * _Nonnull bookModel) {
        if (bookModel.bookSource.bookSourceId && bookModel.bookChapter.link) {
            self.bookModel = bookModel;
            self.bookSource = bookModel.bookSource;
            self.chapter = bookModel.bookChapter.chapterIndex ?: 0;
            self.pageIndex = bookModel.bookContent.pageIndex ?: 0;
            [self loadBookContent:YES chapter:self.chapter];
        }else{
            self.chapter = 0;
            self.pageIndex = 0;
            [self loadBookSummary];
        }
    }];
}
- (UIViewController *)viewControllerAtPage:(NSUInteger)pageIndex chapter:(NSInteger)chapterIndex
{
    GKReadViewController *vc = [[GKReadViewController alloc] init];
    self.pageIndex = pageIndex;
    if (self.chapter != chapterIndex) {
        self.chapter = chapterIndex;
        [self loadBookContent:NO chapter:self.chapter];
    }
    [vc setCurrentPage:pageIndex totalPage:self.bookContent.pageCount chapter:self.chapter title:self.bookContent.title content:[self.bookContent getContentAtt:pageIndex]];
    return vc;
}
//获取源
- (void)loadBookSummary{
    [MBProgressHUD showHUDAddedTo:self.view animated:NO];
    [GKNovelNetManager bookSummary:self.model._id success:^(id  _Nonnull object) {
         [MBProgressHUD hideHUDForView:self.view animated:NO];
        self.bookSource.listData = [NSArray modelArrayWithClass:GKBookSourceModel.class json:object];
        [self loadBookChapters:0];
    } failure:^(NSString * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.view animated:NO];
    }];
}
//获取章节列表
- (void)loadBookChapters:(NSInteger)sourceIndex{
    [MBProgressHUD showHUDAddedTo:self.view animated:NO];
    self.bookSource.sourceIndex = sourceIndex;
    [GKNovelNetManager bookChapters:self.bookSource.bookSourceId success:^(id  _Nonnull object) {
        self.bookChapter = [GKBookChapterInfo modelWithJSON:object];
       [self loadBookContent:NO chapter:self.chapter];
    } failure:^(NSString * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.view animated:NO];
    }];
}
//获取章节内容
- (void)loadBookContent:(BOOL)history chapter:(NSInteger)chapterIndex{
    GKBookChapterModel *model = nil;
    if (history) {
        model = self.bookModel.bookChapter;
    }else if (!self.bookChapter){
        [self loadBookSummary];
        return;
    }
    else if(self.bookChapter.chapters.count > chapterIndex)
    {
        model = self.bookChapter.chapters[chapterIndex];
    }
    else if (self.bookChapter.chapters.count <= chapterIndex){
        [MBProgressHUD hideHUDForView:self.view animated:NO];
        [MBProgressHUD showMessage:@"没有下一章了"];
        return;
    }
    model.chapterIndex = chapterIndex;
    BOOL maxIndex = (self.pageIndex+1 == self.bookContent.pageCount) ? YES : NO;
    [GKBookCacheTool bookContent:model.link contentId:model._id bookId:self.model._id sameSource:self.bookSource.sourceIndex success:^(GKBookContentModel * _Nonnull model) {
        self.bookContent = model;
        [self.bookContent setContentPage];
        [self reloadUI:history maxIndex:maxIndex];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    } failure:^(NSString * _Nonnull error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
}
- (void)reloadUI:(BOOL)history maxIndex:(BOOL)maxIndex
{
    if (!history) {
        self.pageIndex = maxIndex ? self.bookContent.pageCount - 1 : 0;
    }
    [self insertDataQueue];
    UIViewController *vc = [self viewControllerAtPage:self.pageIndex chapter:self.chapter];
    [self.pageViewController setViewControllers:@[vc]
                                      direction:UIPageViewControllerNavigationDirectionReverse
                                       animated:NO
                                     completion:nil];

}
- (void)insertDataQueue{
    GKBookChapterModel *chapterModel = [self.bookChapter.chapters objectSafeAtIndex:self.chapter] ? : self.bookModel.bookChapter;
    GKBookSourceInfo *souceInfo = self.bookSource.bookSourceId ?self.bookSource: self.bookModel.bookSource;
    GKBookContentModel *contentModel = self.bookContent ?: self.bookModel.bookContent;
    chapterModel.chapterIndex = self.chapter;
    contentModel.pageIndex = self.pageIndex;
    
    GKBookReadModel *readModel = [GKBookReadModel vcWithBookId:self.model._id bookSource:souceInfo bookChapter:chapterModel bookContent:contentModel bookModel:self.model];
    [GKBookReadDataQueue insertDataToDataBase:readModel completion:^(BOOL success) {
        if (success) {
            NSLog(@"insert successful");
        }
    }];
}
#pragma mark buttonAction
- (void)tapAction{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapAction) object:nil];
    if (!self.setView.hidden) {
        [self setAction];
    }else{
        self.topView.hidden ? [self tapViewShow] : [self tapViewHidden];
    }
}
- (void)tapViewShow{
    self.topView.hidden = NO;
    self.bottomView.hidden = self.topView.hidden;
    [self.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.topView.superview);
        make.height.offset(NAVI_BAR_HIGHT);
        make.top.equalTo(self.topView.superview).offset(0);
    }];
    CGFloat height = TAB_BAR_ADDING + 49;
    [self.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.bottomView.superview);
        make.height.offset(height);
        make.bottom.equalTo(self.bottomView.superview).offset(0);
    }];
    [UIView animateWithDuration:0.2 animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (finished) {
            [self setNeedsStatusBarAppearanceUpdate];
        }
    }];
}
- (void)tapViewHidden{
    [self.topView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.topView.superview);
        make.height.offset(NAVI_BAR_HIGHT);
        make.top.equalTo(self.topView.superview).offset(-NAVI_BAR_HIGHT);
    }];
    CGFloat height = TAB_BAR_ADDING + 49;
    [self.bottomView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.bottomView.superview);
        make.height.offset(height);
        make.bottom.equalTo(self.bottomView.superview).offset(height);
    }];
    [UIView animateWithDuration:0.2 animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        if (finished) {
            self.topView.hidden = YES;
            self.bottomView.hidden = self.topView.hidden;
            [self setNeedsStatusBarAppearanceUpdate];
        }
    }];
}
- (void)goBack{
    [self insertDataQueue];
    [self goBack:NO];
}
- (void)moreAction{
    GKBookSourceController *vc = [GKBookSourceController vcWithChapter:self.model._id sourceId:self.bookSource.bookSourceId completion:^(NSInteger index) {
        [self loadBookChapters:index];
    }];
    [self.navigationController pushViewController:vc animated:YES];
}
- (void)setAction{
    if (self.setView.hidden) {
        [self.setView loadData];
        self.setView.hidden = NO;
        [self.setView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.setView.superview);
            make.height.offset(gkSetHeight);
            make.bottom.offset(0);
        }];
        [UIView animateWithDuration:0.25 animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            
        }];
    }else{
        [self.setView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.setView.superview);
            make.height.offset(gkSetHeight);
            make.bottom.offset(gkSetHeight);
        }];
        [UIView animateWithDuration:0.25 animations:^{
            [self.view layoutIfNeeded];
        } completion:^(BOOL finished) {
            self.setView.hidden = YES;
        }];
    }
}
- (void)dayACtion:(UIButton *)sender{
    sender.selected = !sender.selected;
    GKReadState state  = (sender.selected == NO) ? GKReadDefault : GKReadBlack;
    [GKReadSetManager setReadState:state];
    self.mainView.image = [GKReadSetManager defaultSkin];
}
- (void)cataACtion:(UIButton *)sender{
    GKBookChapterController *vc = [GKBookChapterController vcWithChapter:self.bookSource.bookSourceId chapter:self.chapter completion:^(NSInteger index) {
        self.chapter = index;
        [self loadBookContent:NO chapter:index];
    }];
    [self.navigationController pushViewController:vc animated:YES];
}
#pragma mark UIPageViewControllerDelegate,UIPageViewControllerDataSource
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerBeforeViewController:(GKReadViewController *)viewController {
    NSInteger pageIndex = viewController.pageIndex;
    NSUInteger chapter = viewController.chapterIndex;
    if (pageIndex == 0 && chapter == 0){
        return nil;
    }
    if (pageIndex >= 0) {
        pageIndex = pageIndex - 1;
    }else{
        chapter = chapter - 1;
        pageIndex = self.bookContent.pageCount - 1;
    }
    return [self viewControllerAtPage:pageIndex chapter:chapter];
    
    
}
#pragma mark 返回下一个ViewController对象
- (UIViewController *)pageViewController:(UIPageViewController *)pageViewController viewControllerAfterViewController:(GKReadViewController *)viewController {
    NSUInteger pageIndex = viewController.pageIndex;
    NSUInteger chapter = viewController.chapterIndex;
    if (pageIndex >= self.bookContent.pageCount) {
        pageIndex = 0;
        chapter = chapter + 1;
    }else{
        pageIndex = pageIndex + 1;
    }
    return [self viewControllerAtPage:pageIndex chapter:chapter];
}
#pragma mark GKReadSetDelegate
- (void)readSetView:(GKReadSetView *)setView brightness:(CGFloat)brightness{
    
}
- (void)readSetView:(GKReadSetView *)setView font:(CGFloat)font{
    [self.bookContent setContentPage];
    self.pageIndex  = self.pageIndex < self.bookContent.pageCount ? self.pageIndex : self.bookContent.pageCount - 1;
    [self insertDataQueue];
    UIViewController *vc = [self viewControllerAtPage:self.pageIndex chapter:self.chapter];
    [self.pageViewController setViewControllers:@[vc]
                                      direction:UIPageViewControllerNavigationDirectionReverse
                                       animated:NO
                                     completion:nil];
}
- (void)readSetView:(GKReadSetView *)setView state:(GKReadState)state{
    self.mainView.image = [GKReadSetManager defaultSkin];
    self.bottomView.dayBtn.selected = [GKReadSetManager shareInstance].model.state == GKReadBlack;
}
#pragma mark get

- (GKReadTopView *)topView{
    if (!_topView) {
        _topView = [GKReadTopView instanceView];
        [_topView.closeBtn addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
        [_topView.moreBtn addTarget:self action:@selector(moreAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _topView;
}
- (GKReadBottomView *)bottomView{
    if (!_bottomView) {
        _bottomView = [GKReadBottomView instanceView];
        [_bottomView.setBtn addTarget:self action:@selector(setAction) forControlEvents:UIControlEventTouchUpInside];
        [_bottomView.dayBtn addTarget:self action:@selector(dayACtion:) forControlEvents:UIControlEventTouchUpInside];
        [_bottomView.cataBtn addTarget:self action:@selector(cataACtion:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _bottomView;
}
- (GKReadSetView *)setView{
    if (!_setView) {
        _setView = [GKReadSetView instanceView];
        _setView.delegate = self;
    }
    return _setView;
}
#pragma mark get

- (GKBookSourceInfo *)bookSource{
    if (!_bookSource) {
        _bookSource = [[GKBookSourceInfo alloc] init];
    }
    return _bookSource;
}
- (UIImageView *)mainView{
    if (!_mainView) {
        _mainView = [[UIImageView alloc] init];
        _mainView.userInteractionEnabled = YES;
        _mainView.clipsToBounds = YES;
        _mainView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _mainView;
}
- (BOOL)prefersStatusBarHidden{
    return self.topView.hidden;
}

@end
