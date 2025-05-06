<?php
//	License for all code of this FreePBX module can be found in the license file inside the module directory
//	Copyright 2015 Sangoma Technologies.
//


$voiceids = array(

				'Aditi' => 'Aditi',
				'Amy' => 'Amy',
				'Astrid' => 'Astrid',
				'Bianca' => 'Bianca',
				'Brian' => 'Brian',
				'Camila' => 'Camila',
				'Carla' => 'Carla',
				'Carmen' => 'Carmen',
				'Celine' => 'Celine',
				'Chantal' => 'Chantal',
				'Conchita' => 'Conchita',
				'Cristiano' => 'Cristiano',
				'Dora' => 'Dora',
				'Emma' => 'Emma',
				'Enrique' => 'Enrique',
				'Ewa' => 'Ewa',
				'Filiz' => 'Filiz',
				'Geraint' => 'Geraint',
				'Giorgio' => 'Giorgio',
				'Gwyneth' => 'Gwyneth',
				'Hans' => 'Hans',
				'Ines' => 'Ines',
				'Ivy' => 'Ivy',
				'Jacek' => 'Jacek',
				'Jan' => 'Jan',
				'Joanna' => 'Joanna',
				'Joey' => 'Joey',
				'Justin' => 'Justin',
				'Karl' => 'Karl',
				'Kendra' => 'Kendra',
				'Kimberly' => 'Kimberly',
				'Lea' => 'Lea',
				'Liv' => 'Liv',
				'Lotte' => 'Lotte',
				'Lucia' => 'Lucia',
				'Lupe' => 'Lupe',
				'Mads' => 'Mads',
				'Maja' => 'Maja',
				'Marlene' => 'Marlene',
				'Mathieu' => 'Mathieu',
				'Matthew' => 'Matthew',
				'Maxim' => 'Maxim',
				'Mia' => 'Mia',
				'Miguel' => 'Miguel',
				'Mizuki' => 'Mizuki',
				'Naja' => 'Naja',
				'Nicole' => 'Nicole',
				'Penelope' => 'Penelope',
				'Raveena' => 'Raveena',
				'Ricardo' => 'Ricardo',
				'Ruben' => 'Ruben',
				'Russell' => 'Russell',
				'Salli' => 'Salli',
				'Seoyeon' => 'Seoyeon',
				'Takumi' => 'Takumi',
				'Tatyana' => 'Tatyana',
				'Vicki' => 'Vicki',
				'Vitoria' => 'Vitoria',
				'Zeina' => 'Zeina',
				'Zhiyu' => 'Zhiyu',
			);

foreach($voiceids as $id){
	$voiceid_opts .= '<option value='.$id.' '.(($id == $config['tts_voiceid'])?"SELECTED":"").'>'.$id.'</option>';
}


$aghtml = '';

?>

<form name="edit" id="edit" class="fpbx-submit" action="" method="POST">
<input type="hidden" value="manageengine" name="display"/>
<input type="hidden" name="action" value="edit">
<!--Default aws access_key_id header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="aws_access_key_id"><?php echo _("aws access_key_id") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="aws_access_key_id"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="aws_access_key_id" name="aws_access_key_id" value="<?php  echo $config['aws_access_key_id']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="aws_access_key_id-help" class="help-block fpbx-help-block"><?php echo _("input aws access_key_id")?></span>
                </div>
        </div>
</div>


<!--Default aws secret_access_key header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="aws_secret_access_key"><?php echo _("aws secret_access_key") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="aws_secret_access_key"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="aws_secret_access_key" name="aws_secret_access_key" value="<?php  echo $config['aws_secret_access_key']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="aws_secret_access_key-help" class="help-block fpbx-help-block"><?php echo _("input aws secret_access_key")?></span>
                </div>
        </div>
</div>


<!--Default twilio account_sid header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="twilio_account_sid"><?php echo _("twilio account_sid") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="twilio_account_sid"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="twilio_account_sid" name="twilio_account_sid" value="<?php  echo $config['twilio_account_sid']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="twilio_account_sid-help" class="help-block fpbx-help-block"><?php echo _("input twilio account_sid")?></span>
                </div>
        </div>
</div>


<!--Default twilio auth_token header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="twilio_auth_token"><?php echo _("twilio auth_token") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="twilio_auth_token"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="twilio_auth_token" name="twilio_auth_token" value="<?php  echo $config['twilio_auth_token']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="twilio_auth_token-help" class="help-block fpbx-help-block"><?php echo _("input twilio auth_token")?></span>
                </div>
        </div>
</div>


<!--Default twilio sms_number header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="twilio_sms_number"><?php echo _("twilio sms_number") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="twilio_sms_number"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="twilio_sms_number" name="twilio_sms_number" value="<?php  echo $config['twilio_sms_number']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="twilio_sms_number-help" class="help-block fpbx-help-block"><?php echo _("input twilio sms_number")?></span>
                </div>
        </div>
</div>


<!--Default whmcs api_username header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="whmcs_api_username"><?php echo _("whmcs api_username") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="whmcs_api_username"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="whmcs_api_username" name="whmcs_api_username" value="<?php  echo $config['whmcs_api_username']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="whmcs_api_username-help" class="help-block fpbx-help-block"><?php echo _("input whmcs api_username")?></span>
                </div>
        </div>
</div>


<!--Default whmcs api_password header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="whmcs_api_password"><?php echo _("whmcs api_password") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="whmcs_api_password"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="whmcs_api_password" name="whmcs_api_password" value="<?php  echo $config['whmcs_api_password']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="whmcs_api_password-help" class="help-block fpbx-help-block"><?php echo _("input whmcs api_password")?></span>
                </div>
        </div>
</div>


<!--Default voicebase access_token header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="voicebase_access_token"><?php echo _("voicebase access_token") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="voicebase_access_token"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="voicebase_access_token" name="voicebase_access_token" value="<?php  echo $config['voicebase_access_token']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="voicebase_access_token-help" class="help-block fpbx-help-block"><?php echo _("input voicebase access_token")?></span>
                </div>
        </div>
</div>


<!--Default recording path header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="recording_path"><?php echo _("recording path") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="recording_path"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="recording_path" name="recording_path" value="<?php  echo $config['recording_path']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="recording_path-help" class="help-block fpbx-help-block"><?php echo _("input recording path")?></span>
                </div>
        </div>
</div>


<!--Default sdpapi user header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="sdpapi_user"><?php echo _("sdpapi user") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="sdpapi_user"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="sdpapi_user" name="sdpapi_user" value="<?php  echo $config['sdpapi_user']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="sdpapi_user-help" class="help-block fpbx-help-block"><?php echo _("input sdpapi user")?></span>
                </div>
        </div>
</div>


<!--Default sdpapi password header-->
<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="sdpapi_password"><?php echo _("sdpapi password") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="sdpapi_password"></i>
                        </div>
                        <div class="col-md-9">
                                <input type="text" class="form-control" id="sdpapi_password" name="sdpapi_password" value="<?php  echo $config['sdpapi_password']; ?>">
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="sdpapi_password-help" class="help-block fpbx-help-block"><?php echo _("input sdpapi password")?></span>
                </div>
        </div>
</div>


<!--Default tts voiceid header-->

<div class="element-container">
        <div class="row">
                <div class="form-group">
                        <div class="col-md-3">
                                <label class="control-label" for="tts_voiceid"><?php echo _("tts voiceid") ?></label>
                                <i class="fa fa-question-circle fpbx-help-icon" data-for="tts_voiceid"></i>
                        </div>
                        <div class="col-md-9">
                                <select class="form-control" id="tts_voiceid" name="tts_voiceid">
                                        <?php echo $voiceid_opts ?>
                                </select>
                        </div>
                </div>
        </div>
        <div class="row">
                <div class="col-md-12">
                        <span id="tts_voiceid-help" class="help-block fpbx-help-block"><?php echo _("tts voiceid")?></span>
                </div>
        </div>
</div>
<?php
//add hooks
$module_hook = moduleHook::create();
echo $module_hook->hookHtml;
?>
</form>
