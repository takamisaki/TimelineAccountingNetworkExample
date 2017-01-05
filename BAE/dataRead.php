<?php
require_once 'functions.php';
connectDB();

$name = $_POST['name'];
$password = $_POST['password'];
$result = mysql_query("SELECT * FROM `test1` WHERE `name`='$name'");

if (mysql_errno()){
    echo mysql_error();
}else {
    $result_arr = mysql_fetch_assoc($result);
    if ($result_arr['password']==$password){
        echo $result_arr['records'];
    }else {
        die("password is wrong");
    }

}
