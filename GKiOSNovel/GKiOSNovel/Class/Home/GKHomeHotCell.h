//
//  GKHomeHotCell.h
//  GKiOSNovel
//
//  Created by wangws1990 on 2019/6/11.
//  Copyright © 2019 wangws1990. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GKBookModel.h"
NS_ASSUME_NONNULL_BEGIN

@interface GKHomeHotCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageV;
@property (weak, nonatomic) IBOutlet UILabel *titleLab;
@property (weak, nonatomic) IBOutlet UIButton *tagBtn;

@property (strong, nonatomic) GKBookModel *model;

@end

NS_ASSUME_NONNULL_END
