<?php
require_once 'functions.php';
?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>All Users</title>
</head>
<body>
<table style="text-align: left;border: solid;">
    <tr>
        <th>id</th>
        <th>name</th>
        <th>password</th>
        <th>records</th>
        <th>delete</th>
    </tr>
    <?php
        $conn = connectDB();
        $result = mysql_query("SELECT * FROM `test1`");
        $dataCount = mysql_num_rows($result);
        for($i=0;$i<$dataCount;$i++){
            $result_arr=mysql_fetch_assoc($result);
            $id=$result_arr['id'];
            $name=$result_arr['name'];
            $password=$result_arr['password'];
            $records=$result_arr['records'];
            echo"<tr>
                    <td>$id</td>
                    <td>$name</td>
                    <td>$password</td>
                    <td>$records</td>
                    <td><a href='deleteUser.php?name=$name'> delete</a> </td>
                </tr>";
        }
    ?>
</table>
</body>
</html>
