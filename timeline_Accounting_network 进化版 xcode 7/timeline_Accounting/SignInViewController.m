#import "SignInViewController.h"
#import "RegisterViewController.h"
#import "SVProgressHUD.h" //弹窗框架

//打印简洁化
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

@interface SignInViewController ()
/** 登录的用户名 */
@property (nonatomic, copy   ) NSString *registedUserName;
/** 下载的用户数据 */
@property (nonatomic, strong ) NSMutableArray *records;
@property (weak, nonatomic) IBOutlet UITextField *userNameTextField; //用户名输入框
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField; //密码输入框
@property (weak, nonatomic) IBOutlet UIButton *showPasswordButton;
@end



@implementation SignInViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    self.showPasswordButton.selected       = NO; //设置默认密文状态
    self.passwordTextField.secureTextEntry = YES; //设置输入框密文状态

}


#pragma mark - **************** 视图显示前的准备

//添加用户名, 弹窗提示注册成功
- (void)viewDidAppear: (BOOL)animated {
    
    self.userNameTextField.text = self.registedUserName;
    self.passwordTextField.text = nil;
    
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC);
    dispatch_after(time, dispatch_get_main_queue(), ^{
        if (self.registedUserName.length != 0) {
            [self showHudWithString:@"注册成功, 请登录"];
        }
    });
}

- (IBAction)showPWClicked:(UIButton *)sender {
    self.showPasswordButton.selected = !self.showPasswordButton.selected;
    
    if (self.passwordTextField.secureTextEntry) {
        self.passwordTextField.secureTextEntry = NO;
    }else {
        self.passwordTextField.secureTextEntry = YES;
    }
}

//返回键点击, 返回主界面, 清空已注册用户名(不然下次进入本页面还是会提示注册成功)
- (IBAction)returnClicked:(UIBarButtonItem *)sender{
    [self dismissViewControllerAnimated:YES completion:^{
        self.registedUserName = nil;
    }];
}


//键盘回收
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UIView *view in self.view.subviews) {
        [view resignFirstResponder];
    }
}


#pragma mark - **************** 登录按钮点击

/*  1. 判断输入合规否
    2. 连接服务器, 取得用户数据, 根据不同反馈进行对应弹窗
    3. 取得数据后返回主界面, 并传数据给主界面
 */
- (IBAction)signInClicked: (UIButton *)sender {
    
    //如果没有输入
    if (self.userNameTextField.text.length == 0 || self.passwordTextField.text.length == 0) {
        [self showHudWithString:@"请输入正确信息"];
        
        //提示框消失后重置输入框
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC);
        dispatch_after(time, dispatch_get_main_queue(), ^{
            self.userNameTextField.text = nil;
            self.passwordTextField.text = nil;
        });
        return;
    }
 
    //如果有输入, 连接服务器, 取得用户数据
    
    //测试用
    //NSURL *url = [NSURL URLWithString:@"http://localhost/appBEA/signIn.php"];
    NSURL *url = [NSURL URLWithString:@"http://takatimeline.duapp.com/signIn.php"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSString *name     = self.userNameTextField.text;
    NSString *password = self.passwordTextField.text;
    NSString *param    = [NSString stringWithFormat:@"name=%@&password=%@",name, password];
    request.HTTPBody   = [param dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSession *session      = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                          completionHandler:^(NSData * _Nullable data,
                                                            NSURLResponse * _Nullable response,
                                                            NSError * _Nullable error){
            if (error){
                [self showHudWithString:@"网络故障, 数据无法下载"];
                return;
            }
            
            //如果服务器返回了有值的 data
            else{
                NSString *feedbackStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if ([feedbackStr containsString:@"found"]) {
                    [self showHudWithString:@"用户不存在"];
                    return;
                }
                
                //如果 data 有数据就解析, 没有数据不解析
                if (data.bytes != 0){
                    NSError *serializationError = nil;
                    self.records = [NSJSONSerialization JSONObjectWithData:data
                                                                   options:NSJSONReadingMutableContainers
                                                                     error:&serializationError];
                    
                    //解析容错处理
                    if (serializationError){
                        [self showHudWithString:@"数据解析错误"];
                        return;
                    }
                }
                
                //清空已注册用户名, 以防下次进入弹出注册成功提示
                self.registedUserName = nil;
                
                //跳转到 showPage, 并传值
                [self dismissViewControllerAnimated:YES completion:^{
                    //传用户名和用户数据给 showPage
                    if (self.transferRecordsAndUserName){
                        self.transferRecordsAndUserName(self.records, self.userNameTextField.text);
                    }
                }];
            }
        }];
    
    [task resume];
}


//配置跳转到注册页面的 segue, 赋值注册页面的 block, 方便获取用户名
- (void)prepareForSegue: (UIStoryboardSegue *)segue sender:(id)sender {
    
    RegisterViewController *registerVC = segue.destinationViewController;
    __weak typeof(self) weakSelf       = self;
    registerVC.transferUserName        = ^(NSString *userName){
    weakSelf.registedUserName          = userName;
    weakSelf.userNameTextField.text    = userName;
    };
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
