<?php
/**
 * Playback on HotKey
 */
namespace FreePBX\modules;
class Manageengine implements \BMO {

	public $POH_format_support = array('wav', 'gsm', 'alaw', 'ulaw');

	public $POH_sound_dir = '/sounds/en/custom';

	public function __construct($freepbx = null) {
		if ($freepbx == null) {
			throw new \Exception("Not given a FreePBX Object");
		}

		global $amp_conf;



		$this->FreePBX = $freepbx;
		$this->db = $freepbx->Database;
		$this->astman = $this->FreePBX->astman;
	}

	public function install() {}
	public function uninstall() {}
	public function backup(){}
	public function restore($backup){}
	public function doConfigPageInit($display) {}

	public function ajaxRequest($req, &$setting) {
		switch($req) {
			case "togglerecording":
				return true;
			break;
		}
		return false;
	}

	public function ajaxHandler() {
		switch( $_REQUEST['command'] ) {
			case "togglerecording":
				return $this->getable();
			break;
		}
	}

	
	public function getActionBar($request) {
		if ($request['display'] === 'manageengine') {
			return array(
					'submit' => array(
						'name' => 'submit',
						'id' => 'submit',
						'value' => _("Submit")
					),
					'reset' => array(
						'name' => 'reset',
						'id' => 'reset',
						'value' => _("Reset"),
					),
				);
		}
	}
	public function showPage() {
		$content = file_get_contents("/etc/aws.cfg");

		foreach (explode("\n", $content) as $line) {
				if (!$line)
						continue;
				list($s, $e) = explode('=', $line);
				if (!($s && $e))
						continue;
		
				$config["$s"] = $e;
		}
		
		$results = $this->check_license();
		
		if ($_REQUEST['showlicense'] == 'true' || $results['status'] != 'Active') {
			if(isset($_REQUEST['action']) && $_REQUEST['action'] == 'updatelicense') {
				$base = __DIR__;

				$textfile = @fopen($base . "/license.txt", "w") or die("Unable to open file!");
				$licensekey = $_REQUEST['license_key'];
				$contents = $licensekey . "\n";
				fwrite($textfile, $contents);
				fclose($textfile);
				header('Location: '.$_SERVER['REQUEST_URI']);
			} else {
				return load_view(__DIR__."/views/licenseform.php",array("licensekey" => $results['saved_licensekey'],
																		"licensestatus" => $results['status'],
																		"description" => $results['description']));
			}
			return;
		}
		
		$content = file_get_contents("/etc/recording.cfg");

		foreach (explode("\n", $content) as $line) {
				if (!$line)
						continue;
				list($s, $e) = explode('=', $line);
				if (!($s && $e))
						continue;
		
				$recording["$s"] = $e;
		}
		
		if(isset($_REQUEST['action']) && $_REQUEST['action'] == 'edit') {
			$content = '[default]' . "\n";
			foreach($config as $k => $v) {
				if (isset($_REQUEST[$k])) {
					$config[$k] = $_REQUEST[$k];
				}
				
				$content .= "$k=" . $config[$k] . "\n";
			}
			
			
			file_put_contents("/etc/aws.cfg", $content);
			$content = '[default]' . "\n";
			foreach($recording as $k => $v) {
				list($old_type, $old_system_recording, $old_tts) = explode('||', $v, 3);
				$type = $_REQUEST["$k-type"];
				$recordingfile = $_REQUEST["$k-recording"];
				if ($type == 'tts') {
					if (isset($_REQUEST[$k])) {
						if ($old_tts != $_REQUEST[$k]) {						
							$this->updaterecording($k, $_REQUEST[$k]);
						}
						$recording[$k] = 'tts||' . $old_system_recording . '||' . $_REQUEST[$k];
					}
				} else {
					$recording[$k] = 'system||' . $recordingfile . '||' . $old_tts;
				}
				
				$content .= "$k=$type||$recordingfile||" . $_REQUEST[$k] .  "\n";
			}
			
			
			file_put_contents("/etc/recording.cfg", $content);
		}
		
		$view = !empty($_REQUEST['view']) ? $_REQUEST['view'] : "";


		return load_view(__DIR__."/views/form.php",array("config" => $config, "recording" => $recording));
	}

	public function getable() {

		$ext = isset($_REQUEST['ext'])?$_REQUEST['ext']:'';
		$state = '';
		if($_REQUEST['state'] == 'enable'){
				$state = 'CHECKED';
		}
		if($_REQUEST['state'] == 'disable'){
				$state = 'UNCHECKED';
		}
		if($state === '' || empty($ext)){
				return array('toggle' => 'invalid');
		}
		$ret = $this->astman->database_put('splittedrecording', $ext, $state);
		
		return array('toggle' => 'received', 'return' => $ret );
	
	}
	
	public function updaterecording($filename, $txt) {
		global $amp_conf;
		require_once($amp_conf['AMPWEBROOT'] . '/admin/modules/manageengine/aws/aws-autoloader.php');

		require_once($amp_conf['AMPWEBROOT'] . '/admin/modules/manageengine/aws/AwsPolly.php');
		
		$content = file_get_contents("/etc/aws.cfg");
		
		foreach (explode("\n", $content) as $line) {
				if (!$line)
						continue;
				list($s, $e) = explode('=', $line);
				if (!($s && $e))
						continue;
		
				$config["$s"] = $e;
		}
		
		#print_r($config);
		$config['region'] = 'us-west-2';
		$polly = new \TBETool\AwsPolly(
			$config['aws_access_key_id'], 
			$config['aws_secret_access_key'], 
			$config['region']
		);
		
		$param = array(
			'language' => 'en-US',
			'voice' => $config['tts_voiceid'],
			'output_path' => '/var/www/html/recording'
		);
		
		$tmpfile = $polly->textToVoice(
			$txt,
			$param
		);
		
		$recording_dir = '/var/lib/asterisk/sounds/whmcs/';
		if(file_exists($tmpfile)) {
			system("ffmpeg -i $tmpfile -ar 8000 -ac 1 $recording_dir$filename.wav");
			unlink($tmpfile);
		}
	}
	
	function check_license() {
		$licensekey = "";
		$localkey = "";
		$base = __DIR__;
		$handle = @fopen($base."/license.txt", "r");
		if ($handle) {
			$count = 0;
			while (($line = fgets($handle)) !== false) {
				// process the line read.
				if ($count == 0) {
					$licensekey = trim($line);
				} else if ($count == 1) {
					$localkey = trim($line);
					break;
				}
				$count++;
			}
		
			fclose($handle);
		} else {
			return array('status' => 'Invalid', 'message' => 'key file not found');
		}
		
		$results = $this->whmcs_check_license($licensekey, $localkey);

		
		// Raw output of results for debugging purpose
		#echo '<textarea cols="100" rows="20">' . print_r($results, true) . '</textarea>';
		
		// Interpret response
		switch ($results['status']) {
			case "Active":
				// get new local key and save it somewhere
				$localkeydata = str_replace(' ','',preg_replace('/\s+/', ' ', $results['localkey']));
				$handle = fopen($base."/license.txt", "r");
				if ($handle) {
					$count = 0;
					while (($line = fgets($handle)) !== false) {
						// process the line read.
						if ($count == 0) {
							$licensekey = trim($line);
							break;
						}
						$count++;
					}
					fclose($handle);
					if (isset($results['localkey'])) {
						$textfile = fopen($base . "/license.txt", "w") or die("Unable to open file!");
						$contents = $licensekey . "\n" . $localkeydata . "\n";
						fwrite($textfile, $contents);
						fclose($textfile);
					}
					$results = array('status' => 'Active');
				} else {
					$results = array('status' => 'Invalid', 'description' => 'key file not readable');
				}
				break;
			case "Invalid":
				$results = array('status' => 'Invalid', 'description' => 'License key is Invalid');
				break;
			case "Expired":
				$results =  array('status' => 'Invalid', 'description' => 'License key is Expired');
				break;
			case "Suspended":
				$results =  array('status' => 'Invalid', 'description' => 'License key is Suspended');
				break;
			default:
				$results =  array('status' => 'Invalid', 'description' => 'Unknown response from server');
				break;
		}
		$results['saved_licensekey'] = $licensekey;
		return $results;
	}
	
	function whmcs_check_license($licensekey, $localkey='') {
		$content = file_get_contents("/etc/aws.cfg");
		
		foreach (explode("\n", $content) as $line) {
				if (!$line)
						continue;
				list($s, $e) = explode('=', $line);
				if (!($s && $e))
						continue;
		
				$config["$s"] = $e;
		}
		$whmcsurl = $config['license_whmcsurl'];
		// Must match what is specified in the MD5 Hash Verification field
		// of the licensing product that will be used with this check.
		$licensing_secret_key = ''; #'FPBXfe89b83751';
		// The number of days to wait between performing remote license checks
		$localkeydays = $config['license_localkeydays']; #15;
		// The number of days to allow failover for after local key expiry
		$allowcheckfaildays = $config['license_allowcheckfaildays'];
	
		// -----------------------------------
		//  -- Do not edit below this line --
		// -----------------------------------
	
		$check_token = time() . md5(mt_rand(1000000000, 9999999999) . $licensekey);
		$checkdate = date("Ymd");
		$domain = $_SERVER['SERVER_NAME'];
		$usersip = isset($_SERVER['SERVER_ADDR']) ? $_SERVER['SERVER_ADDR'] : $_SERVER['LOCAL_ADDR'];
		$dirpath = dirname(__FILE__);
		$verifyfilepath = 'modules/servers/licensing/verify.php';
		$localkeyvalid = false;
		if ($localkey) {
			$localkey = str_replace("\n", '', $localkey); # Remove the line breaks
			$localdata = substr($localkey, 0, strlen($localkey) - 32); # Extract License Data
			$md5hash = substr($localkey, strlen($localkey) - 32); # Extract MD5 Hash
			if ($md5hash == md5($localdata . $licensing_secret_key)) {
				$localdata = strrev($localdata); # Reverse the string
				$md5hash = substr($localdata, 0, 32); # Extract MD5 Hash
				$localdata = substr($localdata, 32); # Extract License Data
				$localdata = base64_decode($localdata);
				$localkeyresults = unserialize($localdata);
				$originalcheckdate = $localkeyresults['checkdate'];
				if ($md5hash == md5($originalcheckdate . $licensing_secret_key)) {
					$localexpiry = date("Ymd", mktime(0, 0, 0, date("m"), date("d") - $localkeydays, date("Y")));
					if ($originalcheckdate > $localexpiry) {
						$localkeyvalid = true;
						$results = $localkeyresults;
						$validdomains = explode(',', $results['validdomain']);
						if (!in_array($_SERVER['SERVER_NAME'], $validdomains)) {
							$localkeyvalid = false;
							$localkeyresults['status'] = "Invalid";
							$results = array();
						}
						$validips = explode(',', $results['validip']);
						if (!in_array($usersip, $validips)) {
							$localkeyvalid = false;
							$localkeyresults['status'] = "Invalid";
							$results = array();
						}
						$validdirs = explode(',', $results['validdirectory']);
						if (!in_array($dirpath, $validdirs)) {
							$localkeyvalid = false;
							$localkeyresults['status'] = "Invalid";
							$results = array();
						}
					}
				}
			}
		}
		if (!$localkeyvalid) {
			$postfields = array(
				'licensekey' => $licensekey,
				'domain' => $domain,
				'ip' => $usersip,
				'dir' => $dirpath,
			);
			if ($check_token) $postfields['check_token'] = $check_token;
			$query_string = '';
			foreach ($postfields AS $k=>$v) {
				$query_string .= $k.'='.urlencode($v).'&';
			}
			if (function_exists('curl_exec')) {
				$ch = curl_init();
				curl_setopt($ch, CURLOPT_URL, $whmcsurl . $verifyfilepath);
				curl_setopt($ch, CURLOPT_POST, 1);
				curl_setopt($ch, CURLOPT_POSTFIELDS, $query_string);
				curl_setopt($ch, CURLOPT_TIMEOUT, 30);
				curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
				$data = curl_exec($ch);
				curl_close($ch);
			} else {
				$fp = fsockopen($whmcsurl, 80, $errno, $errstr, 5);
				if ($fp) {
					$newlinefeed = "\r\n";
					$header = "POST ".$whmcsurl . $verifyfilepath . " HTTP/1.0" . $newlinefeed;
					$header .= "Host: ".$whmcsurl . $newlinefeed;
					$header .= "Content-type: application/x-www-form-urlencoded" . $newlinefeed;
					$header .= "Content-length: ".@strlen($query_string) . $newlinefeed;
					$header .= "Connection: close" . $newlinefeed . $newlinefeed;
					$header .= $query_string;
					$data = '';
					@stream_set_timeout($fp, 20);
					@fputs($fp, $header);
					$status = @socket_get_status($fp);
					while (!@feof($fp)&&$status) {
						$data .= @fgets($fp, 1024);
						$status = @socket_get_status($fp);
					}
					@fclose ($fp);
				}
			}
			if (!$data) {
				$localexpiry = date("Ymd", mktime(0, 0, 0, date("m"), date("d") - ($localkeydays + $allowcheckfaildays), date("Y")));
				if ($originalcheckdate > $localexpiry) {
					$results = $localkeyresults;
				} else {
					$results = array();
					$results['status'] = "Invalid";
					$results['description'] = "Remote Check Failed";
					return $results;
				}
			} else {
				preg_match_all('/<(.*?)>([^<]+)<\/\\1>/i', $data, $matches);
				$results = array();
				foreach ($matches[1] AS $k=>$v) {
					$results[$v] = $matches[2][$k];
				}
				#echo "data:$data<br>\n";
			}
			if (!is_array($results)) {
				die("Invalid License Server Response");
			}
			if (false && $results['md5hash']) { #disable md5hash check
				if ($results['md5hash'] != md5($licensing_secret_key . $check_token)) {
					$results['status'] = "Invalid";
					$results['description'] = "MD5 Checksum Verification Failed";
					return $results;
				}
			}
			if ($results['status'] == "Active") {
				$results['checkdate'] = $checkdate;
				$data_encoded = serialize($results);
				$data_encoded = base64_encode($data_encoded);
				$data_encoded = md5($checkdate . $licensing_secret_key) . $data_encoded;
				$data_encoded = strrev($data_encoded);
				$data_encoded = $data_encoded . md5($data_encoded . $licensing_secret_key);
				$data_encoded = wordwrap($data_encoded, 80, "\n", true);
				$results['localkey'] = $data_encoded;
			}
			$results['remotecheck'] = true;
		}
		unset($postfields,$data,$matches,$whmcsurl,$licensing_secret_key,$checkdate,$usersip,$localkeydays,$allowcheckfaildays,$md5hash);
		return $results;
	}
}
