<?php
//	License for all code of this FreePBX module can be found in the license file inside the module directory
//	Copyright 2015 Sangoma Technologies.
//

require '/var/www/twiliolib/vendor/autoload.php';

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

			$aws_region = array('us-west-1', 'us-west-2','us-east-1', 'us-east-2');
foreach($voiceids as $id){
	$voiceid_opts .= '<option value='.$id.' '.(($id == $config['tts_voiceid'])?"SELECTED":"").'>'.$id.'</option>';
}

foreach($aws_region as $r){
	$aws_region_opts .= '<option value='.$r.' '.(($r == $config['aws_default_region'])?"SELECTED":"").'>'.$r.'</option>';
}


$transcribe_opts .= "<option value='true' " .(($config['transcribe_enabled'] == 'true')?"SELECTED":"").'>'.'true'.'</option>';
$transcribe_opts .= "<option value='false' " .(($config['transcribe_enabled'] == 'false')?"SELECTED":"").'>'.'false'.'</option>';

$recordings = recordings_list(); #print_r($recordings);

use Twilio\Rest\Client;
$twilio = new Client($config['twilio_account_sid'], $config['twilio_auth_token']);
$incomingPhoneNumbers = $twilio->incomingPhoneNumbers->read([], 200);
foreach ($incomingPhoneNumbers as $record) {
	$twilio_sms_number_opts .= '<option value='.$record->phoneNumber.' '.(($record->phoneNumber == $config['twilio_sms_number'])?"SELECTED":"").'>'.$record->phoneNumber.'</option>';
}

$aghtml = '';

?>

 <!--Default aws access_key_id header-->
<ul class="nav nav-tabs" role="tablist">
	<li role="presentation" data-name="general" class="active">
		<a href="#general" aria-controls="general" role="tab" data-toggle="tab">
			<?php echo _("General Settings")?>
		</a>
	</li>
	<li role="presentation" data-name="recording" class="change-tab">
		<a href="#recording" aria-controls="recording" role="tab" data-toggle="tab">
			<?php echo _("Recording Settings")?>
		</a>
	</li>
	<li role="presentation" data-name="license" class="change-tab">
		<a href="?display=manageengine&showlicense=true" aria-controls="license" role="tab2" data-toggle="tab2">
			<?php echo _("Show License")?>
		</a>
	</li>
</ul>
<input type="hidden" name="action" value="edit">

<div class="tab-content display">
	<div role="tabpanel" id="general" class="tab-pane active">
		<?php foreach($config as $key => $val) {
			$tip = $config[$key . '_descr'];
			if ($key == 'tts_voiceid' || $key == 'twilio_sms_number' || $key == 'aws_default_region' || $key == 'transcribe_enabled') {
				continue;
			}
			$hide = '';
			if (substr($key, -6) == '_descr' || $key == 'whmcs_api_username' || $key == 'whmcs_api_password' || $key == 'recording_path' || $key == 'license_whmcsurl' || $key == 'license_localkeydays' || $key == 'license_allowcheckfaildays') {
				$hide = "style='display: none' ";
			}
			
echo <<<C
		<div class="element-container" $hide>
				<div class="row">
					<div class="form-group">
						<div class="col-md-3">
							<label class="control-label" for="$key">$tip</label>
							<i class="fa fa-question-circle fpbx-help-icon" data-for="$key"></i>
						</div>
						<div class="col-md-9">
							<input type="text" class="form-control" id="$key" name="$key" value="$val">
						</div>
					</div>
					<div class="row">
						<div class="col-md-12">
							<span id="$key-help" class="help-block fpbx-help-block">$tip</span>
						</div>
					</div>
				</div>
		</div>
C;
		}
		?>
		<!--Default twilio_sms_number  header-->

		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="twilio_sms_number"><?php echo$config['twilio_sms_number_descr'] ?></label>
										<i class="fa fa-question-circle fpbx-help-icon" data-for="twilio_sms_number"></i>
								</div>
								<div class="col-md-9">
										<select class="form-control" id="twilio_sms_number" name="twilio_sms_number">
												<?php echo $twilio_sms_number_opts ?>
										</select>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="twilio_sms_number-help" class="help-block fpbx-help-block"><?php echo $config['twilio_sms_number_descr'];?></span>
						</div>
				</div>
		</div>
		
		<!--Default tts voiceid header-->
		
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="tts_voiceid"><?php echo $config['tts_voiceid_descr'] ?></label>
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
								<span id="tts_voiceid-help" class="help-block fpbx-help-block"><?php echo $config['tts_voiceid_descr'];?></span>
						</div>
				</div>
		</div>
		
		<!--Default aws_default_region header-->
		
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="aws_default_region"><?php echo $config['aws_default_region_descr'] ?></label>
										<i class="fa fa-question-circle fpbx-help-icon" data-for="aws_default_region"></i>
								</div>
								<div class="col-md-9">
										<select class="form-control" id="aws_default_region" name="aws_default_region">
												<?php echo $aws_region_opts ?>
										</select>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="aws_default_region-help" class="help-block fpbx-help-block"><?php echo  $config['aws_default_region_descr'];?></span>
						</div>
				</div>
		</div>


<!--Default transcribe_enabled header-->
		
		<div class="element-container">
				<div class="row">
						<div class="form-group">
								<div class="col-md-3">
										<label class="control-label" for="transcribe_enabled"><?php echo $config['transcribe_enabled_descr'] ?></label>
										<i class="fa fa-question-circle fpbx-help-icon" data-for="transcribe_enabled"></i>
								</div>
								<div class="col-md-9">
										<select class="form-control" id="transcribe_enabled" name="transcribe_enabled">
												<?php echo $transcribe_opts ?>
										</select>
								</div>
						</div>
				</div>
				<div class="row">
						<div class="col-md-12">
								<span id="transcribe_enabled-help" class="help-block fpbx-help-block"><?php echo $config['transcribe_enabled_descr'];?></span>
						</div>
				</div>
		</div>
	</div>

<!--start recording setting page-->

	<div role="tabpanel" id="recording" class="tab-pane">
		<?php foreach($recording as $filename => $content) {
/*
(
    [0] => Array
        (
            [id] => 1
            [displayname] => annoucement
            [filename] => custom/queue_callback_main
            [description] => annoucment
            [fcode] => 0
            [fcode_pass] => 
            [fcode_lang] => en
            [0] => 1
            [1] => annoucement
            [2] => custom/queue_callback_main
            [3] => annoucment
        )

)
*/
			list($type, $system_recording, $tts_content) = explode('||', $content, 3);
			$filename_tip = $config[$filename.'_descr'];
			if ($type == 'system') {
				$recording_url = "http://" . $_SERVER[HTTP_HOST] . "/sounds/$system_recording.wav";
				$filepath = "/var/lib/asterisk/sounds/$system_recording.wav";
				$system_recording_selected = 'selected';
				$tts_selected = '';

				$system_recording_display = '';
				$tts_display = 'display: none';

			} else {
				$recording_url = "http://" . $_SERVER[HTTP_HOST] . "/whmcs/$filename.wav";
				$filepath = "/var/lib/asterisk/sounds/whmcs/$filename.wav";
				$tts_selected = 'selected';
				$system_recording_selected = '';
				
				$system_recording_display = 'display: none';
				$tts_display = '';
				
			}
			
			if (file_exists($filepath)) {
				$tip =  $filepath . ': ' . filesize($filepath);
			} else {
				$tip = "$filepath not found";
			}
			
			$recording_list_opts = '';
			foreach($recordings as $rec){
				$lan = $rec[fcode_lang] ? $rec[fcode_lang] : 'en';
				$val = $lan . '/' . $rec[filename];
				$recording_list_opts .= "<option value='$val'" . ($val == $system_recording ?  'selected' : '') .' >'.$rec[displayname ].'</option>';
			}
			
echo <<<R
		<div class="element-container">
				<div class="row">
					<div class="form-group">
						<div class="col-md-3" style='width:20%'>
							<label class="control-label" for="$filename"><a target=_blank href='$recording_url'>$filename_tip</a></label>
							<i class="fa fa-question-circle fpbx-help-icon" data-for="$filename"></i>
						</div>
						<div class="col-md-9" style='width: 15%'>
									<select class="form-control" id="$filename-type" name="$filename-type" onchange="switchtype('$filename');">
										<option value='tts' $tts_selected>TTS</option>';
										<option value='system' $system_recording_selected>system recording</option>';
										
									</select>
							</div>
						<div class="col-md-9" style='width: 64%;$tts_display' id="$filename-tts-div" >
							<input type="text" class="form-control" id="$filename" name="$filename" value="$tts_content">
						</div>
						<div class="col-md-9" style='width: 64%;$system_recording_display' id="$filename-recording-div">
									<select class="form-control" id="$filename-recording" name="$filename-recording">
										<option> -- select system recording -- </option>
										$recording_list_opts
									</select>
							</div>
					</div>
					<div class="row">
						<div class="col-md-12">
							<span id="$filename-help" class="help-block fpbx-help-block">$tts_content</span>
						</div>
					</div>
				</div>
		</div>
R;
		}
		?>
		
		
	</div>
</div>

<script>
	function switchtype(name) {
		type = $('#'+name+'-type').val();
		if (type == 'system') {
			$('#'+name+'-tts-div').hide();
			$('#'+name+'-recording-div').show();
		} else {
			$('#'+name+'-tts-div').show();
			$('#'+name+'-recording-div').hide();
		}
	}
</script>
