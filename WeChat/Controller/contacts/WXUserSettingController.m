//
//  WXUserSettingController.m
//  WeChat
//
//  Created by Vincent on 2019/3/24.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "WXUserSettingController.h"
#import "WXUserPermissionController.h"
#import "WXDataValueModel.h"
#import "WXDataValueCell.h"
#import "WXUserPermissionController.h"
#import "WXEditUserInfoSectionHeaderView.h"
#import "WXEditUserInfoViewController.h"
#import "WXContactsSelectController.h"
#import "WXUserViewController.h"
#import "WXSendCardAlertView.h"
#import "WXSession.h"
#import "WXMessage.h"

@interface WXUserSettingController ()
@property (nonatomic, strong) WXUser *user;
@property (nonatomic, strong) NSArray <NSArray <WXDataValueModel *>*>*dataArray;
@end

@implementation WXUserSettingController
- (instancetype)initWithUser:(WXUser *)user {
    if (!user) return nil;
    if (self = [super init]) {
        self.user = user;
        self.title = @"资料设置";
    }
    return self;
}

- (void)createView {
    [super createView];
    
    self.navigationBar.translucent = NO;
    self.navigationBar.shadowView.backgroundColor = VIEW_COLOR;
    self.navigationBar.backgroundColor = VIEW_COLOR;
    
    self.tableView.frame = self.contentView.bounds;
    self.tableView.backgroundColor = VIEW_COLOR;
    self.tableView.separatorColor = SEPARATOR_COLOR;
    self.tableView.rowHeight = 55.f;
    
    UIButton *deleteButton = [UIButton buttonWithFrame:CGRectMake(0.f, 0.f, self.tableView.width_mn, self.tableView.rowHeight)
                                                 image:nil
                                                 title:@"删除"
                                            titleColor:BADGE_COLOR
                                                  titleFont:[UIFont systemFontOfSize:17.f]];
    deleteButton.backgroundColor = UIColor.whiteColor;
    @weakify(self);
    [deleteButton handTapConfiguration:nil eventHandler:^(id sender) {
        @strongify(self);
        [self delete];
    }];
    self.tableView.tableFooterView = deleteButton;
}

- (void)loadData {
    WXDataValueModel *model0 = [WXDataValueModel new];
    model0.title = @"设置备注和标签";
    model0.value = @"0";
    model0.desc = self.user.name;
    WXDataValueModel *model1 = [WXDataValueModel new];
    model1.value = @"0";
    model1.desc = @" ";
    if (self.user.gender == WechatGenderMale) {
        model1.title = @"把他推荐给朋友";
    } else if (self.user.gender == WechatGenderFemale) {
        model1.title = @"把她推荐给朋友";
    } else {
        model1.title = @"把他(她)推荐给朋友";
    }
    WXDataValueModel *model2 = [WXDataValueModel new];
    model2.title = @"设为星标朋友";
    model2.value = @(self.user.asterisk).stringValue;
    WXDataValueModel *model3 = [WXDataValueModel new];
    model3.title = @"朋友权限";
    model3.desc = @" ";
    model3.value = @"0";
    self.dataArray = @[@[model0, model3], @[model1], @[model2]];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    /// 用户信息更新
    @weakify(self);
    [self handNotification:WXUserUpdateNotificationName eventHandler:^(NSNotification *notify) {
        @strongify(self);
        if (![self.user isEqualToUser:notify.object]) return;
        if (self.dataArray.count > 0) {
            WXDataValueModel *model = self.dataArray.firstObject.firstObject;
            model.desc = ((WXUser *)notify.object).name;
            [self.tableView reloadRow:0 inSection:0 withRowAnimation:UITableViewRowAnimationNone];
        }
    }];
}

#pragma mark - UITableViewDataDelegate&Source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataArray.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataArray[section] count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 3) return 25.f;
    return .01f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 10.f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    WXEditUserInfoSectionHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"com.wx.user.info.setting.header"];
    if (!header) {
        header = [[WXEditUserInfoSectionHeaderView alloc] initWithReuseIdentifier:@"com.wx.user.info.setting.header"];
    }
    header.titleLabel.text = section == 3 ? @"朋友圈和视频动态" : @"";
    return header;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    MNTableViewHeaderFooterView *footer = [tableView dequeueReusableHeaderFooterViewWithIdentifier:@"com.wx.user.info.setting.footer"];
    if (!footer) {
        footer = [[MNTableViewHeaderFooterView alloc] initWithReuseIdentifier:@"com.wx.user.info.setting.footer"];
        footer.contentView.backgroundColor = VIEW_COLOR;
    }
    return footer;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WXDataValueCell *cell = [tableView dequeueReusableCellWithIdentifier:@"com.wx.user.info.setting.list.cell"];
    if (!cell) {
        cell = [[WXDataValueCell alloc] initWithReuseIdentifier:@"com.wx.user.info.setting.list.cell" size:CGSizeMake(tableView.width_mn, tableView.rowHeight)];
        @weakify(self);
        cell.valueChangedHandler = ^(NSIndexPath *indexPath, BOOL isOn) {
            [weakself updateUserSetting:indexPath isOn:isOn];
        };
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(WXDataValueCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= self.dataArray.count) return;
    NSArray <WXDataValueModel *>*section = self.dataArray[indexPath.section];
    if (indexPath.row >= section.count) return;
    WXDataValueModel *row = section[indexPath.row];
    cell.model = row;
    cell.switchButton.hidden = indexPath.section <= 1;
    cell.detailLabel.hidden = (indexPath.section + indexPath.row > 0);
    cell.imgView.hidden = !cell.switchButton.isHidden;
    if (indexPath.row == section.count - 1) {
        cell.separatorInset = UIEdgeInsetsZero;
    } else {
        cell.separatorInset = UIEdgeInsetsMake(0.f, cell.titleLabel.left_mn, 0.f, 0.f);
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            WXEditUserInfoViewController *vc = [[WXEditUserInfoViewController alloc] initWithUser:self.user];
            [self.navigationController pushViewController:vc animated:YES];
        } else {
            WXUserPermissionController *vc = [[WXUserPermissionController alloc] initWithUser:self.user];
            [self.navigationController pushViewController:vc animated:YES];
        }
    } else if (indexPath.section == 1) {
        @weakify(self);
        WXContactsSelectController *viewController = WXContactsSelectController.new;
        viewController.expelUsers = @[self.user];
        viewController.selectedHandler = ^(WXContactsSelectController *vc) {
            @strongify(self);
            // 弹出确定发送弹窗
            WXSendCardAlertView *alertView = WXSendCardAlertView.new;
            alertView.user = self.user;
            alertView.toUser = vc.users.firstObject;
            @weakify(vc);
            // 用户信息查看
            alertView.userClickHandler = ^(WXSendCardAlertView *aView) {
                @strongify(vc);
                WXUserViewController *infoController = [[WXUserViewController alloc] initWithUser:aView.toUser];
                [vc.navigationController pushViewController:infoController animated:YES];
            };
            // 确定发送
            [alertView showInView:vc.view completionHandler:^(WXSendCardAlertView *aView) {
                @strongify(vc);
                [self sendCardToUser:aView.toUser msg:aView.text inViewController:vc];
            }];
        };
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (void)sendCardToUser:(WXUser *)toUser msg:(NSString *)text inViewController:(UIViewController *)vc {
    @weakify(vc);
    __block BOOL isSucceed = NO;
    __block WXSession *session = nil;
    [vc.view showWechatDialogDelay:.35f eventHandler:^{
        session = [WXSession sessionForUser:toUser];
        NSArray <WXMessage *>*msgs = [WXMessage createCardMsg:self.user text:text isMine:YES session:session];
        if (msgs.count <= 0) return;
        if (![MNDatabase.database updateTable:WXSessionTableName where:@{sql_field(session.identifier):session.identifier}.componentString model:session]) return;
        @PostNotify(WXSessionTableReloadNotificationName, nil);
        isSucceed = YES;
    } completionHandler:^{
        @strongify(vc);
        if (isSucceed) {
            [vc.navigationController popViewControllerAnimated:YES];
        } else {
            [vc.view showInfoDialog:@"推荐失败"];
        }
    }];
}

#pragma mark - 更新用户设置
- (void)updateUserSetting:(NSIndexPath *)indexPath isOn:(BOOL)isOn {
    @weakify(self);
    WXUser *user = self.user;
    [self.view showWechatDialogDelay:.3f eventHandler:^{
        if ([MNDatabase.database updateTable:WXContactsTableName where:@{sql_field(user.uid):sql_pair(user.uid)}.sqlQueryValue fields:@{sql_field(user.asterisk):@(isOn).stringValue}]) {
            user.asterisk = isOn;
            weakself.dataArray.lastObject.lastObject.value = @(isOn).stringValue;
            @PostNotify(WXUserUpdateNotificationName, user);
            [weakself.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }
    } completionHandler:nil];
}

#pragma mark - 删除用户
- (void)delete {
    @weakify(self);
    MNActionSheet *actionSheet = [MNActionSheet actionSheetWithTitle:@"同时删除与该联系人的聊天记录" cancelButtonTitle:@"取消" handler:^(MNActionSheet *sheet, NSInteger buttonIndex) {
        if (buttonIndex == sheet.cancelButtonIndex) return;
        [weakself.view showWechatDialogDelay:.3f eventHandler:^{
            @strongify(self);
            @PostNotify(WXUserDeleteNotificationName, self.user)
        } completionHandler:^{
            @strongify(self);
            if ([self.navigationController seekViewControllerOfClass:NSClassFromString(@"WXChatViewController")]) {
                [self.navigationController popToRootViewControllerAnimated:YES];
            } else {
                [self.navigationController popViewControllerAnimated:YES];
            }
        }];
    } otherButtonTitles:@"删除", nil];
    actionSheet.buttonTitleColor = BADGE_COLOR;
    [actionSheet showInView:self.view];
}

#pragma mark - controller config
- (UITableViewStyle)tableViewStyle {
    return UITableViewStyleGrouped;
}

@end
