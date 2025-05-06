<?php
if (!defined('FREEPBX_IS_AUTH')) { die('No direct script access allowed'); }
//      License for all code of this FreePBX module can be found in the license file inside the module directory
//      Copyright 2015 Sangoma Technologies.
//

$fmrows = '';
foreach($extension_list as $extension){
				$fm = $extension['ext'];
				$val = $extension['splittedrecording'];
        $fmrows .= '<tr>';
        $fmrows .= '<td><a href="#"><i class="fa fa-edit"></i>&nbsp;'.$fm.'</a></td>';
        $fmrows .= '<td>';
        $fmrows .= '<span class="radioset">';
        $fmrows .= '<input type="radio" name="recordingtoggle'.$fm.'" id="recordingtoggle'.$fm.'yes" data-for="'.$fm.'" '.($val == 'CHECKED'?'CHECKED':'').'>';
        $fmrows .= '<label for="recordingtoggle'.$fm.'yes">'._("Yes").'</label>';
        $fmrows .= '<input type="radio" name="recordingtoggle'.$fm.'" id="recordingtoggle'.$fm.'no" data-for="'.$fm.'" '.($val == 'CHECKED'?'':'CHECKED' ).' value="CHECKED">';
        $fmrows .= '<label for="recordingtoggle'.$fm.'no">'._("No").'</label>';
        $fmrows .= '</span>';
}
?>

<table data-show-columns="true" data-toggle="table" data-pagination="true" data-search="true" class="table table-striped">
<thead>
        <tr>
                <th data-sortable="true"><?php echo _("Splitted Recording Extension")?></th>
                <th class="col-xs-3"><?php echo _("Enabled")?></th>
        </tr>
</thead>
<tbody>
        <?php echo $fmrows ?>
</tbody>
</table>