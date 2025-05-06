<?php
if (!defined('FREEPBX_IS_AUTH')) { die('No direct script access allowed'); }

#echo FreePBX::Manageengine()->showPage();

?>

<div class="container-fluid">
        <h1><?php echo _('ManageEngine Integration')?></h1>
        <div class = "display full-border">
                <div class="row">
                        <div class="col-sm-12">
                                <div class="fpbx-container">
                                        <div class="display no-border">
                                                <form name="edit" id="edit" class="fpbx-submit" action="" method="POST">
                                                <input type="hidden" value="manageengine" name="display"/>
                                               
                                                        <?php echo FreePBX::Manageengine()->showPage();?>
                                                </form>
                                        </div>
                                </div>
                        </div>
                </div>
        </div>
</div>
