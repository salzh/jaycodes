<?php
if (!defined('FREEPBX_IS_AUTH')) { die('No direct script access allowed'); }

//
if (!file_exists($lf) ) {
	system("touch /etc/aws.cfg");
}

out(_('ok'));

?>
