<?php require_once('Connections/db.php'); ?><?php
if (!function_exists("GetSQLValueString")) {
function GetSQLValueString($theValue, $theType, $theDefinedValue = "", $theNotDefinedValue = "") 
{
  $theValue = get_magic_quotes_gpc() ? stripslashes($theValue) : $theValue;

  $theValue = function_exists("mysql_real_escape_string") ? mysql_real_escape_string($theValue) : mysql_escape_string($theValue);

  switch ($theType) {
    case "text":
      $theValue = ($theValue != "") ? "'" . $theValue . "'" : "NULL";
      break;    
    case "long":
    case "int":
      $theValue = ($theValue != "") ? intval($theValue) : "NULL";
      break;
    case "double":
      $theValue = ($theValue != "") ? "'" . doubleval($theValue) . "'" : "NULL";
      break;
    case "date":
      $theValue = ($theValue != "") ? "'" . $theValue . "'" : "NULL";
      break;
    case "defined":
      $theValue = ($theValue != "") ? $theDefinedValue : $theNotDefinedValue;
      break;
  }
  return $theValue;
}
}

$maxRows_DetailRS1 = 20;
$pageNum_DetailRS1 = 0;
if (isset($_GET['pageNum_DetailRS1'])) {
  $pageNum_DetailRS1 = $_GET['pageNum_DetailRS1'];
}
$startRow_DetailRS1 = $pageNum_DetailRS1 * $maxRows_DetailRS1;

$colname_DetailRS1 = "-1";
if (isset($_GET['recordID'])) {
  $colname_DetailRS1 = $_GET['recordID'];
}
mysql_select_db($database_db, $db);
$query_DetailRS1 = sprintf("SELECT * FROM cdr  WHERE uniqueid = %s", GetSQLValueString($colname_DetailRS1, "text"));
$query_limit_DetailRS1 = sprintf("%s LIMIT %d, %d", $query_DetailRS1, $startRow_DetailRS1, $maxRows_DetailRS1);
$DetailRS1 = mysql_query($query_limit_DetailRS1, $db) or die(mysql_error());
$row_DetailRS1 = mysql_fetch_assoc($DetailRS1);

if (isset($_GET['totalRows_DetailRS1'])) {
  $totalRows_DetailRS1 = $_GET['totalRows_DetailRS1'];
} else {
  $all_DetailRS1 = mysql_query($query_DetailRS1);
  $totalRows_DetailRS1 = mysql_num_rows($all_DetailRS1);
}
$totalPages_DetailRS1 = ceil($totalRows_DetailRS1/$maxRows_DetailRS1)-1;
?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Untitled Document</title>
</head>

<body>
<? 

$dir = "monitor/";

if ($row_DetailRS1['uniqueid'] != '') { 
	$cmd = "/bin/ls $dir | grep {$row_DetailRS1['uniqueid']}";
} else { 
	$cmd = "/bin/ls $dir | grep {$_GET['callDate']}";
}
//echo "$cmd<br>";
$fp = popen($cmd, "r");

while (!feof($fp)) {

        $file = fgets($fp, 100);
        $file = preg_replace('/\n/','',$file);

	?><a href="monitor/<?= $file ?>"><? echo $file; ?></a><br>
<?  
}
pclose($fp);
?>
<!--
<table border="1" align="center">
  <tr>
    <td>calldate</td>
    <td><?php echo $row_DetailRS1['calldate']; ?> </td>
  </tr>
  <tr>
    <td>clid</td>
    <td><?php echo $row_DetailRS1['clid']; ?> </td>
  </tr>
  <tr>
    <td>src</td>
    <td><?php echo $row_DetailRS1['src']; ?> </td>
  </tr>
  <tr>
    <td>dst</td>
    <td><?php echo $row_DetailRS1['dst']; ?> </td>
  </tr>
  <tr>
    <td>dcontext</td>
    <td><?php echo $row_DetailRS1['dcontext']; ?> </td>
  </tr>
  <tr>
    <td>channel</td>
    <td><?php echo $row_DetailRS1['channel']; ?> </td>
  </tr>
  <tr>
    <td>dstchannel</td>
    <td><?php echo $row_DetailRS1['dstchannel']; ?> </td>
  </tr>
  <tr>
    <td>lastapp</td>
    <td><?php echo $row_DetailRS1['lastapp']; ?> </td>
  </tr>
  <tr>
    <td>lastdata</td>
    <td><?php echo $row_DetailRS1['lastdata']; ?> </td>
  </tr>
  <tr>
    <td>duration</td>
    <td><?php echo $row_DetailRS1['duration']; ?> </td>
  </tr>
  <tr>
    <td>billsec</td>
    <td><?php echo $row_DetailRS1['billsec']; ?> </td>
  </tr>
  <tr>
    <td>disposition</td>
    <td><?php echo $row_DetailRS1['disposition']; ?> </td>
  </tr>
  <tr>
    <td>amaflags</td>
    <td><?php echo $row_DetailRS1['amaflags']; ?> </td>
  </tr>
  <tr>
    <td>accountcode</td>
    <td><?php echo $row_DetailRS1['accountcode']; ?> </td>
  </tr>
  <tr>
    <td>uniqueid</td>
    <td><?php echo $row_DetailRS1['uniqueid']; ?> </td>
  </tr>
  <tr>
    <td>userfield</td>
    <td><?php echo $row_DetailRS1['userfield']; ?> </td>
  </tr>
</table>
-->
<a href="javascript:history.go(-1)">Go back</a> 

</body>
</html><?php
mysql_free_result($DetailRS1);
?>

