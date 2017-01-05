<?php
require_once 'functions.php';

connectDB();

$name = $_POST['name'];
$password = $_POST['password'];

if(empty($name) or empty($password)){
    echo('name or password is empty');

}else {
    $result = mysql_query("SELECT * FROM `test1` WHERE `name`='$name'");

    if (mysql_errno()) {
        echo mysql_error();

    } else {
        $result_arr = mysql_fetch_assoc($result);
        if (empty($result_arr)){
            echo ('User not found');
        }else{
            if ($password != $result_arr['password']) {
                echo('password is wrong');

            } else {
                echo $result_arr['records'];
            }
        }
    }
}