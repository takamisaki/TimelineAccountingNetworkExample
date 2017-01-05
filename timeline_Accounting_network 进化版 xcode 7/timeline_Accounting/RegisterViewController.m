#import "RegisterViewController.h"
#import "SVProgressHUD.h" //弹窗框架

//打印简洁化
#define NSLog(FORMAT, ...) fprintf(stderr,"%s\n",[[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);

@interface RegisterViewController ()
@property (weak, nonatomic) IBOutlet UITextField *userNameTextField;  //输入用户名的文本框
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;  //输入密码的文本框
@property (weak, nonatomic) IBOutlet UIButton    *showPasswordButton; //切换密码明文密文状态的按钮
@end



@implementation RegisterViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.showPasswordButton.selected       = NO; //设置默认密文状态
    self.passwordTextField.secureTextEntry = YES; //设置输入框密文状态
}


-(void)viewDidAppear:(BOOL)animated{
    [SVProgressHUD dismiss];  //清除可能存在的弹框
}


#pragma mark - **************** 按键 action


//密码明文密文状态切换
- (IBAction)showPWClicked:(UIButton *)sender {
    
    self.showPasswordButton.selected = !self.showPasswordButton.selected;
    
    if (self.passwordTextField.secureTextEntry) {
        self.passwordTextField.secureTextEntry = NO;
    }else {
        self.passwordTextField.secureTextEntry = YES;
    }
}


//返回按钮点击: 直接返回, 无操作
- (IBAction)returnClicked: (UIBarButtonItem *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}


/*  注册按钮点击
    1. 判断输入框内容是否合规
    2. 创建网络连接, 进行注册, 根据反馈进行相应的弹窗
 */
- (IBAction)registClicked: (UIButton *)sender {
    
    if (self.userNameTextField.text.length == 0 || self.passwordTextField.text.length == 0) {
        [self showHudWithString:@"请输入正确信息"];
        return;
    }
    
    //测试用
    //NSURL *url = [NSURL URLWithString:@"http://localhost/appBEA/register.php"];
    NSURL *url = [NSURL URLWithString:@"http://takatimeline.duapp.com/register.php"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    
    NSString *strBody  = [NSString stringWithFormat:@"name=%@&password=%@",
                         self.userNameTextField.text,self.passwordTextField.text];
    request.HTTPBody   = [strBody dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSession *session  = [NSURLSession sharedSession];
    NSURLSessionTask *task = [session dataTaskWithRequest:request
                                        completionHandler:^(NSData * _Nullable data,
                                                            NSURLResponse * _Nullable response,
                                                            NSError * _Nullable error)
    {
        if (error) {
            [self showHudWithString:@"网络故障,请稍后再重试"];
        
        }else {
            
            //重名处理
            NSString *feedbackStr = [[NSString alloc] initWithData:data
                                                          encoding:NSUTF8StringEncoding];
            if ([feedbackStr containsString:@"Duplicate"]) {
                [self showHudWithString:@"注册名重复,请使用其他注册名"];
                
                //提示框消失后重置输入框
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC);
                dispatch_after(time, dispatch_get_main_queue(), ^{
                    self.userNameTextField.text = @"";
                    self.passwordTextField.text = @"";
                });
                return;
            }
            
            //如果没有重名, 返回到登录页面, 并把刚注册的用户名传过去, 省去重新输入的动作
            [self dismissViewControllerAnimated:YES completion:^{
                self.transferUserName(self.userNameTextField.text);
            }];
        }
    }];
    [task resume];
}


//键盘回收
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    for (UIView *view in self.view.subviews) {
        [view resignFirstResponder];
    }
}


#pragma mark - **************** 弹窗


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
