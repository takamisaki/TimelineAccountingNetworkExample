<?php
require_once 'functions.php';
connectDB();
$name = intval($_GET['name']);
mysql_query("DELETE FROM users WHERE name='$name'");
header("Location:allUsers.php");