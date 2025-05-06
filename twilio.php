<?php
    $from = $_REQUEST[From];
    $from = str_replace('+', '', $from);
    $to = $_REQUEST[To];
    $to = str_replace('+', '', $to);
    $body = $_REQUEST[Body];
    $ts = date('Ymdhns');
    $file = "/var/www/html/sms/$from-$to.sms";
    $fp = fopen($file, "w");
    $d = fwrite($fp, $body);
    fclose($fp);
    echo "ok: $d bytes write to $file\n";
?>
