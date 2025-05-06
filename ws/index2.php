<?php require_once('Connections/db.php'); ?>
<?php

if ($_GET['logout'] == 1) { 
	session_destroy();
}

$account = $_SERVER['PHP_AUTH_USER'];

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

$currentPage = $_SERVER["PHP_SELF"];

$maxRows_Recordset1 = 100;
$pageNum_Recordset1 = 0;
if (isset($_GET['pageNum_Recordset1'])) {
  $pageNum_Recordset1 = $_GET['pageNum_Recordset1'];
}
$startRow_Recordset1 = $pageNum_Recordset1 * $maxRows_Recordset1;

$colname_Recordset1 = "-1";

if (!isset($_POST['startdate'])) { 
	$_POST['startdate'] = $_SESSION['startdate'];
}

if (isset($_POST['startdate'])) {
	$colname_Recordset1 = $_POST['startdate'];
	$colname_start = $_POST['startdate'] . ' 00:00:00';
	$_SESSION['startdate'] = $_POST['startdate'];
}

$colname_endRecordset1 = "-1";
if (!isset($_POST['enddate'])) { 
	$_POST['enddate'] = $_SESSION['enddate'];
}

if (isset($_POST['enddate'])) {
	$colname_endRecordset1 = $_POST['enddate'];
	$colname_end = $_POST['enddate'] . '23:59:59';
	$_SESSION['enddate'] = $_POST['enddate'];

}
$colname_src = "";
if (!isset($_POST['src'])) { 
	$_POST['src'] = $_SESSION['src'];
}

if (isset($_POST['src'])) {
  $colname_src = trim($_POST['src']);
  $_SESSION['src'] = $_POST['src'];
}


mysql_select_db($database_db, $db);
//echo "$colname_start $colname_end";
if ($colname_start != "" && $colname_end != "") {
	$date_sql = sprintf("AND calldate >= %s AND calldate <= %s",
		GetSQLValueString($colname_start, "date"),
		GetSQLValueString($colname_end, "date"));
} elseif($colname_start != "" && $colname_end == "") {
	$date_sql = sprintf("AND calldate >= %s",
		GetSQLValueString($colname_start, "date"));
} elseif($colname_start == "" && $colname_end != "") {
	$date_sql = sprintf("AND calldate <= %s",
		GetSQLValueString($colname_end, "date"));
} else {
	$date_sql = "";
}
$query_Recordset1 = sprintf("SELECT * FROM calls wHERE tenant=%s %s AND (src LIKE '%%%s%%' OR dst LIKE '%%%s%%') ORDER BY calldate DESC", 
	GetSQLValueString($account, "text"),
	$date_sql,
	$colname_src,
	$colname_src);

//echo $query_Recordset1;

$query_limit_Recordset1 = sprintf("%s LIMIT %d, %d", $query_Recordset1, $startRow_Recordset1, $maxRows_Recordset1);
$Recordset1 = mysql_query($query_limit_Recordset1, $db) or die(mysql_error());
$row_Recordset1 = mysql_fetch_assoc($Recordset1);

if (isset($_GET['totalRows_Recordset1'])) {
  $totalRows_Recordset1 = $_GET['totalRows_Recordset1'];
} else {
  $all_Recordset1 = mysql_query($query_Recordset1);
  $totalRows_Recordset1 = mysql_num_rows($all_Recordset1);
}
$totalPages_Recordset1 = ceil($totalRows_Recordset1/$maxRows_Recordset1)-1;

$queryString_Recordset1 = "";
if (!empty($_SERVER['QUERY_STRING'])) {
  $params = explode("&", $_SERVER['QUERY_STRING']);
  $newParams = array();
  foreach ($params as $param) {
    if (stristr($param, "pageNum_Recordset1") == false && 
        stristr($param, "totalRows_Recordset1") == false) {
      array_push($newParams, $param);
    }
  }
  if (count($newParams) != 0) {
    $queryString_Recordset1 = "&" . htmlentities(implode("&", $newParams));
  }
}
$queryString_Recordset1 = sprintf("&totalRows_Recordset1=%d%s", $totalRows_Recordset1, $queryString_Recordset1);
?><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>Call Recordings</title>
<style type="text/css">
<!--
body {
	font: 10pt Verdana, Arial, Helvetica, sans-serif;
	background: #666666;
	margin: 0; 
	padding: 0;
	text-align: center; 
	color: #000000;
}

.oneColElsCtrHdr #container {
	width: 100%;  
	background: #FFFFFF;
	margin: 0 auto; 
	border: 1px solid #000000;
	text-align: left; 
}
.oneColElsCtrHdr #header { 
	background: #FFFFFF; 
	padding: 0 10px 0 20px;  
} 
.oneColElsCtrHdr #header h1 {
	margin: 0; 
	text-align: right;
	padding-right: 20px;
}
.oneColElsCtrHdr #mainContent {
	width: 90%;
	padding: 10px 10px 0px 30px; 
	background: #FFFFFF;
}
.oneColElsCtrHdr #footer { 
	padding: 0 10px; 
	background:#DDDDDD;
} 
.oneColElsCtrHdr #footer p {
	margin: 0; 
	padding: 10px 0; 
}
-->
</style>
<script type="text/javascript" src="datetimepicker_css.js"></script>
</head>

<body class="oneColElsCtrHdr">

<div id="container">
  <div id="header" style="vertical-align: top;">
<img src="pbxm-logo.png" align="left"> &nbsp;
    <h1>Call Recordings</h1>
  <!-- end #header --></div><br />
<div style="background: #dddddd; padding: 4px 20px 4px 20px;height:25px">
<div style="float:left">
<form method="POST" action="index.php">
Start: <input type="text" name="startdate" id="startdate" value="<? echo ($colname_Recordset1==-1)?'':$colname_Recordset1  ?>" size="12" /> <a href="javascript:NewCssCal('startdate','yyyymmdd','dropdown',false,24,false)">
<img src="images/cal.gif" alt="Pick a date" width="16" height="16" border="0" align="baseline"></a>
End: <input type="text" name="enddate" id="enddate" value="<? echo ($colname_endRecordset1==-1)?'':$colname_endRecordset1  ?>" size="12" /> <a href="javascript:NewCssCal('enddate','yyyymmdd','dropdown',false,24,false)">
<img src="images/cal.gif" alt="Pick a date" width="16" height="16" border="0" align="baseline"></a>
Number: <input type=text name=src value="<? echo $colname_src; ?>">
<input type=submit name=submit value="Go >">
</form>
</div>
<div style="float: right">
Logged in as <?= $account ?>
</div>
</div>
  <div id="mainContent">
    <table border="0" cellpadding="2" cellspacing="0" align="left" width="100%">
      <tr>
        <th>calldate</th>
        <th>direction</th>
        <th align="right">src</th>
        <th align="right">dst</th>
        <th align="right">disposition</th>
        <th align="right">length</th>
        <th align="right">size</th>
        <th align="right">action</th>
      </tr>
<? 

$hostname_db = "66.113.90.100";
$database_db = "asteriskcdrdb";
$username_db = "root";
$password_db = "passw0rd";
$db2 = mysql_pconnect($hostname_db, $username_db, $password_db) or trigger_error(mysql_error(),E_USER_ERROR); 
mysql_select_db($database_db, $db2);

do { 

$sql = "select disposition, billsec from cdr where calldate='$row_Recordset1[calldate]' and userfield='$account'";
$rs2 = mysql_query($sql, $db2) or die(mysql_error());
$row_rs2 = mysql_fetch_assoc($rs2);

$bgcolor = ($bgcolor == "#EEE") ? "#FFF" : "#EEE";

?>
        <tr style="padding:0; background: <?= $bgcolor; ?>;">
          <td><?php echo $row_Recordset1['calldate']; ?></td>
          <td><?php echo $row_Recordset1['calltype']; ?></td>
          <td align="right"><?php echo $row_Recordset1['src']; ?></td>
          <td align="right"><?php echo $row_Recordset1['dst']; ?></td>
          <td align="right"><?php echo $row_rs2['disposition']; ?></td>
          <td align="right"><?php echo $row_rs2['billsec']; ?></td>
          <td align="right"><?php echo intval(filesize("monitor/".$row_Recordset1['filename'])/1000) . "k"; ?></td>
          <td align="right">&nbsp;&nbsp;&nbsp;<a target="_blank" href="monitor/<?php echo $row_Recordset1['filename']; ?>">recording</a></td>
        </tr>
        <?php } while ($row_Recordset1 = mysql_fetch_assoc($Recordset1)); ?>
    </table>
    <br />
    <table border="0">
      <tr>
        <td><?php if ($pageNum_Recordset1 > 0) { // Show if not first page ?>
              <a href="<?php printf("%s?pageNum_Recordset1=%d%s", $currentPage, 0, $queryString_Recordset1); ?>">First</a>
              <?php } // Show if not first page ?>
        </td>
        <td><?php if ($pageNum_Recordset1 > 0) { // Show if not first page ?>
              <a href="<?php printf("%s?pageNum_Recordset1=%d%s", $currentPage, max(0, $pageNum_Recordset1 - 1), $queryString_Recordset1); ?>">Previous</a>
              <?php } // Show if not first page ?>
        </td>
        <td><?php if ($pageNum_Recordset1 < $totalPages_Recordset1) { // Show if not last page ?>
              <a href="<?php printf("%s?pageNum_Recordset1=%d%s", $currentPage, min($totalPages_Recordset1, $pageNum_Recordset1 + 1), $queryString_Recordset1); ?>">Next</a>
              <?php } // Show if not last page ?>
        </td>
        <td><?php if ($pageNum_Recordset1 < $totalPages_Recordset1) { // Show if not last page ?>
              <a href="<?php printf("%s?pageNum_Recordset1=%d%s", $currentPage, $totalPages_Recordset1, $queryString_Recordset1); ?>">Last</a>
              <?php } // Show if not last page ?>
        </td>
      </tr>
    </table>
    Records <?php echo ($startRow_Recordset1 + 1) ?> to <?php echo min($startRow_Recordset1 + $maxRows_Recordset1, $totalRows_Recordset1) ?> of <?php echo $totalRows_Recordset1 ?>
    <!-- end #mainContent -->
  </div>
  <div id="footer">
    <p>&nbsp;</p>
  <!-- end #footer --></div>
<!-- end #container --></div>
</body>
</html>
<?php
mysql_free_result($Recordset1);
?>

