<?php
require_once 'functions.php';
connectDB();
$name = $_POST['name'];
$records = $_POST['records'];
mysql_query("UPDATE `test1` SET `records`='$records' WHERE `test1`.`name`='$name'");
if (mysql_errno()){
    echo mysql_error();
}else{
    echo 'records upload succeed';
}