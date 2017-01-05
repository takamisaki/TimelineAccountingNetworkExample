#import "ViewController.h"
#import "AppTableView.h"
#import "HeaderView.h"
#import "LeftAppCell.h"
#import "RightAppCell.h"
#import "Record.h"
#import "AppDelegate.h"
#import "AddRecordViewController.h"
#import "AppSegue.h"
#import "AppSegueUnwind.h"
#import "SignInViewController.h"
#import "recordModel.h"
#import "MJExtension.h"   //字典数组和模型数组的转换框架
#import "SVProgressHUD.h" //弹窗框架

//打印简洁化
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);


@interface ViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, weak  ) IBOutlet HeaderView      *headerview;           //上方+号栏
@property (nonatomic, weak  ) IBOutlet AppTableView    *tableView;            //下方表格栏
@property (nonatomic, strong) NSManagedObjectContext   *managedObjectContext; //coreData上下文
@property (nonatomic, strong) NSMutableArray<Record *> *recordArray;          //coreData记录数组
@property (nonatomic, strong) NSFetchRequest           *fetch;                //查询对象
@property (nonatomic, strong) Record                   *recordOfCellClicked;  //点击的cell对应的记录
@property (nonatomic, assign) NSUInteger               cellClickedIndex;      //接收被点击cell的index
@property (nonatomic, copy  ) NSString                 *userName;             //signIn传的用户名
@property (nonatomic, copy  ) NSArray                  *records;              //signIn传的用户数据
@property (nonatomic, copy  ) NSString                 *isUploaded;           //标记当前数据是否已上传
@property (nonatomic, copy  ) NSString                 *currentUserName;      //标记当前用户名(离线)
@property (nonatomic, strong) NSUserDefaults           *userDefault;          //保存标记的用户默认
@property (nonatomic, strong) NSMutableArray           *recordDictArray;      //把 coredata 数据转换成字典数组, 再转换成 JSON

@end



@implementation ViewController


#pragma mark - **************** 视图载入准备


/*  1.生成记录数组
    2.配置 tableview
 */
- (void)viewDidLoad {
    [super viewDidLoad];
    
    //取出用户数据
    self.userDefault          = [NSUserDefaults standardUserDefaults];
    self.currentUserName      = [self.userDefault objectForKey:@"currentUserName"];
    self.isUploaded           = [self.userDefault objectForKey:@"isUploaded"];
    
    //生成记录数组
    AppDelegate *appDelegate  = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.managedObjectContext = appDelegate.managedObjectContext;
    self.fetch                = [NSFetchRequest fetchRequestWithEntityName:@"Record"];
    
    
    //配置 tableView
    _tableView.delegate   = self;
    _tableView.dataSource = self;
}


-(void)viewWillAppear:(BOOL)animated {
}


- (void)viewDidAppear:(BOOL)animated{
    [self refreshDataAndShow]; //更新 tableview
}


#pragma mark - **************** TableView & Header 刷新


/*  1.生成记录的倒序数组, 使新纪录可以出现在上面
    2.刷新 Header 的收支总计
 */
- (void)refreshDataAndShow {
    
    //生成倒序数组
    NSArray *recordArrayTemp = [_managedObjectContext executeFetchRequest:_fetch error:nil];
    self.recordArray         = [NSMutableArray new];
    int arrayCount           = (int)recordArrayTemp.count;
    
    //倒序
    for (int index = arrayCount - 1; index >= 0; index --) {
        
        Record *recordTemp = recordArrayTemp[index];
        [self.recordArray addObject:recordTemp];
    }
    
    [_tableView reloadData]; //tableview 刷新数值
    
    //刷新 Header
    [self calculateSum];
    
    //如果登录后传过来了在线的用户名, 开始尝试上传
    if (!(self.userName.length==0)) {
        [self tryUploadData];
    }
}


#pragma mark - **************** 尝试上传

/*  1. 把模型数组转换成字典数组, 方便转换为 JSON
    2. 尝试上传, 根据不同反馈弹出对应窗口
    3. 把上传结果记录到 self.isUploaded 和用户默认, 标记是否已上传
 */
- (void)tryUploadData {
    
    //Record 数组->字典数组
    self.recordDictArray = [Record mj_keyValuesArrayWithObjectArray:self.recordArray];

    NSError *JsonError   = nil;
    NSData *arrayToJson  = [NSJSONSerialization dataWithJSONObject:self.recordDictArray
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:&JsonError];
    if (JsonError) {
        [self showHudWithString:@"数组 to JSON 失败"];
        return;
    };
    
    NSString *arrayToJsonToString = [[NSString alloc] initWithData:arrayToJson
                                                          encoding:NSUTF8StringEncoding];
    
    //测试用
    //NSURL *url                 = [NSURL URLWithString:@"http://localhost/appBEA/dataWrite.php"];
    NSURL *url                   = [NSURL URLWithString:@"http://takatimeline.duapp.com/dataWrite.php"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod           = @"POST";
    
    NSString *param  = [NSString stringWithFormat:@"name=%@&records=%@",self.userName,arrayToJsonToString];
    request.HTTPBody = [param dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSession *session      = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^(NSData * _Nullable data,
                                                                NSURLResponse * _Nullable response,
                                                                NSError * _Nullable error)
                      {
                          if (error) {
                              self.isUploaded = @"NO";
                              [self.userDefault setObject:self.isUploaded forKey:@"isUploaded"];
                              [self showHudWithString:@"网络故障,已存到本地,网络修复后会自动保存到服务器"];
                              
                          }else {
                              self.isUploaded = @"YES";
                              [self.userDefault setObject:self.isUploaded forKey:@"isUploaded"];
                              [self showHudWithString:@"已保存到服务器"];
                          }
                      }];
    [task resume];
}


#pragma mark - **************** 计算收支加总


/*  1.遍历记录数组, 截取每个记录的数值
    2.根据收支分类, 分别加总
    3.传值给 Header 进行显示
 */
- (void)calculateSum {
    
    float incomeSum  = 0.0;  //初始化收入加总值
    float outcomeSum = 0.0;  //初始化支出加总值
    
    for (Record *recordTemp in self.recordArray) {
        
        //截取出数值部分
        NSString *countString = [recordTemp valueForKey:@"count"];
        NSRange range         = [countString rangeOfString:@"￥"];
        float countValue      = [countString substringFromIndex:range.location+1].floatValue;
        
        //分类加总
        if ([[recordTemp valueForKey:@"type"] isEqualToString:@"income"]) {
            incomeSum  += countValue;
        } else {
            outcomeSum += countValue;
        }
    }
    
    //传值给 header
    self.headerview.incomeSumLabel .text = [NSString stringWithFormat:@"￥%.2f",incomeSum ];
    self.headerview.outcomeSumLabel.text = [NSString stringWithFormat:@"￥%.2f",outcomeSum];
}


//设置tableview 的显示row 数
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _recordArray.count;
}


#pragma mark - **************** Cell的配置和显示

/*  1. 获取对应 row 的记录, 利用多态根据identifier重用, 设置 cell 的时间记录默认不显示
    2. 判断是否需要显示cell 的时间记录
 */
- (UITableViewCell *)tableView: (AppTableView *)tableView
         cellForRowAtIndexPath: (NSIndexPath  *)indexPath {
    
    Record *record = self.recordArray [indexPath.row];
    NSString *type = [record valueForKey:@"type"];
    AppCell *cell  = [AppCell new];
    
    //如果是收入类型
    if ([type isEqualToString:@"income"]) {
        NSString *identifier = @"leftCell";
        cell    = (LeftAppCell *)[tableView dequeueReusableCellWithIdentifier:identifier
                                                               forIndexPath:indexPath];
        cell.timeLabel.hidden = YES;
    
    //如果是支出类型
    }else {
        NSString *identifier = @"rightCell";
        cell = (RightAppCell *)[tableView dequeueReusableCellWithIdentifier:identifier
                                                             forIndexPath:indexPath];
        cell.timeLabel.hidden = YES;
    }
    
    //判定是否显示记录时间
    //如果是最上面的记录, 显示
    if (indexPath.row == 0) {
        cell.timeLabel.hidden = NO;

    //如果不是最上面的, 且本记录与它上面的记录的时间不同, 显示.
    } else {
        Record *recordPre = self.recordArray [indexPath.row -1];
        if (![record.time isEqualToString:recordPre.time]) {
            cell.timeLabel.hidden = NO;
        }
    }
    
    [self cellConfiguration:cell with:record forIndex:indexPath.row];
    [self cellButtonBlock:cell];
    return cell;
}


/*  配置具体 cell 需要调用的方法
    1. cell:   该 row 对应的 cell
    2. record: 该 row 对应的记录
    3. index:  该 row
 */
- (void)cellConfiguration: (AppCell *)cell with:(Record *)record forIndex:(NSUInteger)index {
    
    NSString *textString = [NSString stringWithFormat:@"%@ %@",[record valueForKey:@"subType"],
                            [record valueForKey: @"count"]];
    [cell setValue:record.time forKeyPath:@"timeLabel.text"];
    [cell setValue:textString  forKeyPath:@"contentLabel.text"];                          //显示内容
    [cell setValue:@4          forKeyPath:@"contentLabel.layer.cornerRadius"];            //圆角
    [cell setValue:@YES        forKeyPath:@"contentLabel.clipsToBounds"];
    [cell.middleButton         setImage:[UIImage imageNamed:[record valueForKey:@"icon"]] //图标
                               forState:UIControlStateNormal];
    cell.index    = index; //设定cell 对应的 index, 用于按钮 block
    cell.isExpand = false; //折叠图标
}


/*  cell 的修改按钮和删除按钮方法, 通过 block 设置
    1. 参数 cell 表示按钮所属于的 cell
    2. delete block 获取按钮所在的 cell, 找出对应的记录, 删除, 弹窗, 成功后也弹窗, refresh tableView
    3. modify block 先在 prepareForSegue 里设置对应的记录传值, 然后在 block 里调用 segue
 */
- (void)cellButtonBlock: (AppCell *)cell {
    
    __weak typeof(self) weakSelf = self;
    
    //cell 的删除按钮 block 配置
    cell.deleteButtonBlock = ^(NSUInteger index){
        
        //提示弹窗的创建和配置
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示"
                                                                         message:@"确认删除吗?"
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        
        //弹窗的确认按钮配置
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确认"
                                                           style:UIAlertActionStyleDestructive
                                                         handler:^(UIAlertAction * _Nonnull action){
            weakSelf.recordOfCellClicked = weakSelf.recordArray[index];
            [weakSelf.managedObjectContext deleteObject:weakSelf.recordOfCellClicked];
            [weakSelf.managedObjectContext save:nil];
            [self showHudWithString:@"数据已保存"];
            
            weakSelf.isUploaded = @"NO";
            [weakSelf.userDefault setObject:weakSelf.isUploaded forKey:@"isUploaded"];
            
            dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC);
            dispatch_after(time, dispatch_get_main_queue(), ^{
                [weakSelf refreshDataAndShow];
            });
        }];
        
        //弹窗的取消按钮配置
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction * _Nonnull action) {
            return;
        }];
        
        
        [alertVC addAction:okAction];
        [alertVC addAction:cancelAction];
        [self presentViewController:alertVC animated:YES completion:nil];
    };
    
    //cell 的修改按钮 block 配置
    cell.modifyButtonBlock = ^(NSUInteger index){
        self.cellClickedIndex = index;
        [weakSelf performSegueWithIdentifier:@"appSegue" sender:weakSelf];
    };
}


#pragma mark - **************** 本页面到其他页面 segue 的配置


/*  1. 判断 segue 的 identifier, 进行不同的设置
    2. 如果是 cell 的修改按钮激活的, 传值给要跳转的页面 addRecordVC, 供修改
    3. 如果是横栏 + 号激活的, 不传值给要跳转的页面 addRecordVC
    3. 如果是顶部返回按钮激活的, 设置要跳转的页面 signInVC 的 block 供回传用户名和数据
    4. signIn 取得数据回传后, 根据 isUploaded 的标识判断是否需要上传数据 or 解析数据保存在本地
 */
- (void)prepareForSegue: (UIStoryboardSegue *)segue sender:(id)sender {

    AddRecordViewController *destionationVC = segue.destinationViewController;
    
    //如果是 modify 按钮激活的 segue, 传值
    //如果无记录, 就不传值. (解决空白记录时, 点+ 导致 crash.)
    if ([segue.identifier isEqualToString:@"appSegue"]) {
        self.recordOfCellClicked = self.recordArray[self.cellClickedIndex];
        [destionationVC setValue:self.recordOfCellClicked forKey:@"record"];
        [destionationVC setValue:@NO forKey:@"isFromAdd"]; //标记不是 add激活的 segue
        
    //如果是 add 激活的 segue
    } else if ([segue.identifier isEqualToString:@"addSegue"]) {
        [destionationVC setValue:@YES forKey:@"isFromAdd"];
    
    //如果是返回按钮激活的 segue
    } else if ([segue.identifier isEqualToString:@"showSignIn"]) {
        
        SignInViewController *signInVC      = segue.destinationViewController;
        __weak typeof(self) weakSelf        = self;
        signInVC.transferRecordsAndUserName = ^(NSArray *records, NSString *userName){
           
            weakSelf.records = records;
            
            if ([weakSelf.isUploaded isEqualToString:@"NO"]) {
                [weakSelf tryUploadData];
            
            }else {
                [weakSelf downloadArrayToCoreData];
            }

            weakSelf.userName = userName;
            
            //用于本地多用户, 没有完善该情况.
            weakSelf.currentUserName = userName;
            [weakSelf.userDefault setObject:weakSelf.currentUserName forKey:@"currentUserName"];
        };
    }
}


/*  下载的用户数据转换为本地数据并保存
    1. 遍历本地数据, 全部删除
    2. 遍历下载数据, 写入 coreData, refresh tableView
 */
- (void)downloadArrayToCoreData {
    
    [self showHudWithString:@"正在解析数据"];
    
    int count = (int)self.records.count;
    
    NSArray<Record *> *oldRecordArray = [self.managedObjectContext executeFetchRequest:self.fetch
                                                                                 error:nil];
    
    for (Record *tempRecord in oldRecordArray) {
        [self.managedObjectContext deleteObject:tempRecord];
        [self.managedObjectContext save:nil];
    }
    
    for (int index = count-1; index >= 0; index--) {
        NSDictionary *dict = (NSDictionary *)self.records[index];
        Record *record = [NSEntityDescription insertNewObjectForEntityForName:@"Record"
                                                       inManagedObjectContext:self.managedObjectContext];
        
        [record setValuesForKeysWithDictionary:dict];
        [self.managedObjectContext save:nil];
    }
    [self refreshDataAndShow];
}


//用于 unwind segue执行的方法
- (IBAction)returnFromSegueActions: (UIStoryboardSegue *)sender{
    
}


- (UIStoryboardSegue *)segueForUnwindingToViewController:(UIViewController *)toViewController
                                      fromViewController:(UIViewController *)fromViewController
                                              identifier:(NSString *)identifier {
    
    if ([identifier isEqualToString:@"appSegueUnwind"]) {
    
        UIStoryboardSegue *unwindSegue = [AppSegueUnwind segueWithIdentifier:@"appSegueUnwind"
                                                                      source:fromViewController
                                                                 destination:toViewController
                                                              performHandler:^{
                                                                  nil;
                                                              }];
        return unwindSegue;
    }
    return [super segueForUnwindingToViewController:toViewController
                                 fromViewController:fromViewController
                                         identifier:identifier];
}


//取消按钮点击高亮
- (BOOL)tableView: (UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath{
    return NO;
}


//返回按钮点击事件, 跳转到 signInVC
- (IBAction)returnClicked:(UIBarButtonItem *)sender {
    [self performSegueWithIdentifier:@"showSignIn" sender:self];
}


//弹窗时间为2秒, 显示内容是参数 string
- (void)showHudWithString: (NSString *)string {
    
    [SVProgressHUD setDefaultMaskType:SVProgressHUDMaskTypeBlack];
    [SVProgressHUD showWithStatus:string];
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_main_queue(), ^{
        [SVProgressHUD dismiss];
    });
}

@end
