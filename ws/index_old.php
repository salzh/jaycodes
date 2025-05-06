<?php require_once('Connections/db.php'); ?>
<?php
$_SESSION["recording_login"] = true;
if (!isset($_SESSION["recording_login"]) || $_SESSION["recording_login"] != true) {
    header("Location: /call_recordings/login.php?action=LogIn", TRUE, 301);
    exit(0);
}

$filename = isset($_REQUEST['filename']) ? $_REQUEST['filename'] : '';
if (strlen($filename) > 5) {
	$filename = "/var/spool/asterisk/monitor/$filename";
	header("Connection: Keep-Alive");
	header("Transfer-Encoding: chunked");
	header('Content-Type: audio/wav');
	header("Content-Length: " . filesize($filename));
	$fh = fopen($filename, "rb") or die("fail to open $filename");
	$buffer = fread($fh, filesize($filename));
	print $buffer;
	exit;
}
$account = isset($_SERVER['PHP_AUTH_USER']) ? $_SERVER['PHP_AUTH_USER'] : '';
$account = 'test';	

if (strlen($account) < 1) {
	header("Location: /call_recordings/login.php?action=LogIn", TRUE, 301);
    exit(0);
}

if (isset($_POST['jobid'])) {
	$jobid = $_POST['jobid'];
}

if (isset($_POST['useraction']) && $_POST['useraction'] == 'stop') {
	if (file_exists("/tmp/start_dial")) {
		unlink("/tmp/start_dial");
	}
	file_put_contents ("/tmp/stop_dial", '0');
	echo "<red> Stop Request Send, please wait a moment ... <br></red>\n";
	unset($jobid);

} elseif (isset($_POST['useraction']) && $_POST['useraction'] == 'start') {
	file_put_contents ("/tmp/start_dial", '0');
	echo "<red> Check Request Send, please wait a moment ... <br></red>\n";
	
	unset($jobid);

} elseif (isset($_POST['useraction']) && $_POST['useraction'] == 'export') {
	#echo "<red> Export Request Send, please wait a moment ... <br></red>\n";
	ob_start();
} elseif (isset($_POST['useraction'])) {
}


if (!function_exists("GetSQLValueString")) {
function GetSQLValueString($theValue, $theType, $theDefinedValue = "", $theNotDefinedValue = "") 
{
	global $db;
  $theValue = get_magic_quotes_gpc() ? stripslashes($theValue) : $theValue;

  $theValue = mysqli_escape_string($db, $theValue);

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

$maxRows_Recordset1 = 500;
$pageNum_Recordset1 = 0;
if (isset($_GET['pageNum_Recordset1'])) {
  $pageNum_Recordset1 = $_GET['pageNum_Recordset1'];
}
$startRow_Recordset1 = $pageNum_Recordset1 * $maxRows_Recordset1;

$colname_Recordset1 = "-1";

if (!isset($_REQUEST['startdate'])) {
	if (isset($_SESSION['startdate']) && $_SESSION['startdate'] != '' && $_SESSION['startdate']) {
		$_REQUEST['startdate'] = $_SESSION['startdate'];
	}
}

if (isset($_REQUEST['startdate'])) {
  $colname_Recordset1 = $_REQUEST['startdate'];
  $colname_start = $_REQUEST['startdate'] . ' 00:00:00';
  //$colname_end = $_REQUEST['startdate'] . '23:59:59';

	$_SESSION['startdate'] = $_REQUEST['startdate'];

}

$colname_endRecordset1 = "-1";
if (!isset($_REQUEST['enddate']) ) {
	if (isset($_SESSION['enddate']) && $_SESSION['enddate'] != '' && $_SESSION['enddate']) {
		$_REQUEST['enddate'] = $_SESSION['enddate'];
	}
}

if (isset($_REQUEST['enddate'])) {
  $colname_endRecordset1 = $_REQUEST['enddate'];
  $colname_end = $_REQUEST['enddate'] . '23:59:59';

	$_SESSION['enddate'] = $_REQUEST['enddate'];

}
$colname_src = "";
if (!isset($_REQUEST['src'])) { 
	$_REQUEST['src'] = isset($_SESSION['src']) ? $_SESSION['src'] : '';
}



if (isset($_SESSION['TENANT_ID'])) {
	$_REQUEST['tenant'] = $_SESSION['TENANT_ID'];
}
if (!isset($_REQUEST['tenant'])) {
	$_REQUEST['tenant'] = '';
}
if (isset($_REQUEST['src'])) {
  $colname_src = trim($_REQUEST['src']);
  $_SESSION['src'] = $_REQUEST['src'];
}

if (isset($_REQUEST['disposition'])) {
	$disposition = trim($_REQUEST['disposition']);
} else {
	$disposition = '';
}

$_SESSION['disposition'] = $disposition;

//mysqli_select_db($database_db, $db);
//echo "$colname_start $colname_end";
if (!isset($colname_start)) {
	$colname_start = "";
}

if (!isset($colname_end)) {
	$colname_end = "";
}

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

if ($_REQUEST['tenant'] == '') {
	$tenant_sql = ' 1=1 ';
} else {
	$tenant_sql = " tenant='" .$_REQUEST['tenant']."' ";
}

if ($disposition != "") {
	$disposition_sql = " disposition='$disposition' ";
	if ($disposition == 'ANSWERED') {
		$recording_sql = ' recordingfile is not null';
	} else {
		$recording_sql = ' 1=1 ';
	}
} else {
	$disposition_sql = " 1=1 ";
	$recording_sql = ' recordingfile is not null';
}

$disposition_option = '';
foreach (array('', 'ANSWERED', 'NO ANSWER', 'BUSY', 'FAILED') as $v) {
    $disposition_option = $disposition_option . "<option value='$v' " . ($disposition == $v ? 'selected' : '') . " > $v </>\n"; 
}

if (!isset($jobid)) {
	$result = mysqli_query($db, "SELECT jobid FROM did_check_log   ORDER BY jobid DESC limit 1") or  die(mysqli_error($db));
	while ($row = mysqli_fetch_assoc($result)) {
		$jobid    = $row['jobid'];
		break;
	}
}

if (!$jobid) {
	echo "No job found!<br>\n";
	exit(0);
}

$result = mysqli_query($db, "SELECT distinct(jobid),cdatetime FROM did_check_log  ORDER BY jobid DESC") or  die(mysqli_error($db));
$jobid_option_list = '';
while ($row = mysqli_fetch_assoc($result)) {
	$jobid_option_list .= "<option value=" .  $row['jobid'] . ($jobid==$row['jobid'] ? ' selected': '') .">" . $row['cdatetime'] . "</option>";
}

$query_Recordset1 = sprintf("SELECT * FROM did_check_log wHERE jobid='%s' order by result desc", $jobid);

#echo $query_Recordset1;

$query_limit_Recordset1 = sprintf("%s LIMIT %d, %d", $query_Recordset1, $startRow_Recordset1, $maxRows_Recordset1);

$Recordset1 = mysqli_query($db,$query_limit_Recordset1) or die(mysqli_error($db));
$row_Recordset1 = mysqli_fetch_assoc($Recordset1);

//print_r($row_Recordset1);

if (isset($_GET['totalRows_Recordset1'])) {
  $totalRows_Recordset1 = $_GET['totalRows_Recordset1'];
} else {
  $all_Recordset1 = mysqli_query($db, $query_Recordset1);
  $totalRows_Recordset1 = mysqli_num_rows($all_Recordset1);
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
	margin: 0; /* it's good practice to zero the margin and padding of the body element to account for differing browser defaults */
	padding: 0;
	text-align: center; /* this centers the container in IE 5* browsers. The text is then set to the left aligned default in the #container selector */
	color: #000000;
}

.oneColElsCtrHdr #container {
	width: 100%;  /* this width will create a container that will fit in an 800px browser window if text is left at browser default font sizes */
	background: #FFFFFF;
	margin: 0 auto; /* the auto margins (in conjunction with a width) center the page */
	border: 1px solid #000000;
	text-align: left; /* this overrides the text-align: center on the body element. */
}
.oneColElsCtrHdr #header { 
	background: #FFFFFF; 
	padding: 0 10px 0 20px;  /* this padding matches the left alignment of the elements in the divs that appear beneath it. If an image is used in the #header instead of text, you may want to remove the padding. */
} 
.oneColElsCtrHdr #header h1 {
	margin: 0; /* zeroing the margin of the last element in the #header div will avoid margin collapse - an unexplainable space between divs. If the div has a border around it, this is not necessary as that also avoids the margin collapse */
	text-align: right;
	padding-right: 20px;
}
.oneColElsCtrHdr #mainContent {
	width: 90%;
	padding: 10px 10px 0px 30px; /* remember that padding is the space inside the div box and margin is the space outside the div box */
	background: #FFFFFF;
}
.oneColElsCtrHdr #footer { 
	padding: 0 10px; /* this padding matches the left alignment of the elements in the divs that appear above it. */
	background:#DDDDDD;
} 
.oneColElsCtrHdr #footer p {
	margin: 0; /* zeroing the margins of the first element in the footer will avoid the possibility of margin collapse - a space between divs */
	padding: 10px 0; /* padding on this element will create space, just as the the margin would have, without the margin collapse issue */
}
-->
</style>
<script type="text/javascript" src="datetimepicker_css.js"></script>
</head>

<body class="oneColElsCtrHdr">

<div id="container">
  <div id="header" style="vertical-align: top;">
<img src="pbxm-logo.png" align="left"> &nbsp;
    <h1>DID CHECK</h1>
  <!-- end #header --></div><br />
<br><div style="background: #dddddd; padding-left: 20px; padding-top: 4px; height:25px">
<div style="float:left">
<form method="POST" action="index.php" id='mainform'>
<input type=hidden name=useraction id=useraction />
Select Job: <select name=jobid  onchange="javascript:this.form.submit();"> <?php echo $jobid_option_list; ?></select>&nbsp;&nbsp;&nbsp;
<input type=submit  value="Export" onClick="return do_action('export');">

Total: <span id=total><?php echo $totalRows_Recordset1 ?></span>
Success: <span id=ok style='color: green'>0</span>&nbsp;&nbsp;

</div>
<div style="float: right">
<input type=submit  value="Restart New Check" onClick="return do_action('start');">
<input type=submit value="Stop Check" onClick="return do_action('stop');">

</div>
</div>
<br>
</form>

  <div id="mainContent">
    <table border="0" cellpadding="2" cellspacing="0" align="left" width="100%">
      <tr>
        <th>Date Time</th>
        <th>DID</th>
        <th>Result</th>
      </tr>
<?php
$ok = 0;
$csv_body = '';
do {
	$bgcolor = (isset($bgcolor) && $bgcolor == "#EEE") ? "#FFF" : "#EEE";
 
	if (!$row_Recordset1['result']){
	   $did = $row_Recordset1['did'];
	   
	   $result = mysqli_query($db, "SELECT dst FROM cdr  where src='$jobid' and dst='$did'") or  die(mysqli_error($db));
	   if (mysqli_num_rows($result) > 0) {
		   mysqli_query($db, "update did_check_log set result='ok'  where did='$did' and jobid='$jobid'") or  die(mysqli_error($db));
		   $row_Recordset1['result'] = 'ok';$ok++;
		} 
	} else {
		$ok++;
	}
	
	$csv_body .= $row_Recordset1['cdatetime'] . ',' . $row_Recordset1['did'] . ',' .  $row_Recordset1['result'] . "\n";
	
 
?>
        <tr style="padding:0; background: <?php echo $bgcolor; ?>;">
          <td><?php echo $row_Recordset1['cdatetime']; ?></td>
          <td><?php echo $row_Recordset1['did']; ?></td>
          <td><?php echo $row_Recordset1['result']; ?></td>
        </tr>
        <?php } while ($row_Recordset1 = mysqli_fetch_assoc($Recordset1)); ?>
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
    Records <?php echo ($startRow_Recordset1 + 1) ?> to <?php echo min($startRow_Recordset1 + $maxRows_Recordset1, $totalRows_Recordset1) ?> of <?php echo $totalRows_Recordset1 ?>
    <!-- end #mainContent -->
  </div>
  <div id="footer">
    <p>&nbsp;</p>
  <!-- end #footer --></div>
<!-- end #container --></div>
</body>
<script type="text/javascript">
	var span = document.getElementById("ok");
    
	span.innerHTML= '<?php echo $ok ?>';
	
	function myrefresh() 
	{ 
	//window.location.reload(); 
	}
	
	function do_action(a) {
		if (a == "export") {
			document.getElementById('useraction').value='export';
			return confirm('Are You sure to export');
		} else if (a == 'start') {
			document.getElementById('useraction').value='start';
			return confirm('Are You sure to start new check job');
		}else if (a == 'stop') {
			document.getElementById('useraction').value='stop';
			return confirm('Are You sure to stop check job');
		} else {
			document.getElementById('mainform').submit();
		}
	}
	//setTimeout('myrefresh()',10000);
	
</script>

</html>
<?php
if ($_POST['useraction'] == 'export') {
	ob_end_clean();
	header('Content-Type: application/vnd.ms-excel');  
    header("Content-Disposition: attachment;filename=$jobid.csv");  
    header('Cache-Control: max-age=0');
	echo $csv_body;
  
}
mysqli_free_result($Recordset1);
?>

