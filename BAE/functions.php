<?php
require_once 'config.php';
function connectDB(){
    $conn = mysql_connect(MYSQL_HOST,MYSQL_USER,MYSQL_PW);
    if(!$conn){
        die('cannot connect host');
    }
    // mysql_select_db('testDatabase');
    mysql_select_db('nTYIniuzMvcZFAMQAkeg');
    return $conn;
}
