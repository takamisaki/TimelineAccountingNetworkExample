<?php
require_once 'functions.php';
connectDB();
$name = $_POST['name'];
if(empty($name)){
    die('name is empty');
}
$password = $_POST['password'];
if(empty($password)){
    die('password is empty');
}
mysql_query("INSERT INTO `test1` (`id`, `name`, `password`, `records`) VALUES ('', '$name', '$password', '')");
if(mysql_errno()){
    echo mysql_error();
}else{
//    header("Location:allUsers.php");
    echo "register succeed";
}