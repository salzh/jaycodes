<?php

$hostname_db = "localhost";
$database_db = "asterisk";
$username_db = "freepbxuser";
$password_db = "F+vB7DS5kCAL";
#$db = mysql_pconnect($hostname_db, $username_db, $password_db) or trigger_error(mysql_error(),E_USER_ERROR); 
$db=new mysqli($hostname_db, $username_db, $password_db)  or trigger_error(mysqli_connect_error(),E_USER_ERROR);
mysqli_select_db($db, $database_db);
?>
