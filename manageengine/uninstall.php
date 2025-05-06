<?php
if (!defined('FREEPBX_IS_AUTH')) { die('No direct script access allowed'); }

$lf = "/etc/aws.cfg";
if (file_exists($lf) ) {
	#system("mv $lf $lf.bak");
}

?>
