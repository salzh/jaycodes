#!/usr/bin/perl
#======================================================
# start script 
#======================================================
unshift(@INC,"/salzh/perl5/site", "/salzh/perl5"); 
use Asterisk::AGI;
use URI::Escape;
use File::Copy;
$AGI = new Asterisk::AGI;
use Paws::Credential::File;
use Paws;
use Paws::Transcribe::Media;
use WWW::Twilio::API;
use Data::Dumper;
use JSON; # to install, # sudo cpan JSON
use LWP::Simple;
use MIME::Base64;
$aws_region = 'us-west-2';
$config_file = "/etc/aws.cfg";
$bucketname = 'backuprecordings';

$ini = Config::INI::Reader->read_file($config_file);$recording_ini =  Config::INI::Reader->read_file('/etc/recording.cfg');

require "/salzh/code/ivr/lib/default.include.pl";
%call_data  = ();
%call_data = $AGI->ReadParse();
foreach(@ARGV){($n,$v)=split(/\=/,$_); $call_data{"arg_$n"} = $v}
#--------------------------
# configuration start
#--------------------------
$call_data{system_host}  		= $host_name;
$call_data{system_agi}  		= "ticket.pl";
#--------------------------
# configuration stop
#--------------------------
$call_data{system_pid}  		= &clean_int($$);
$call_data{call_did} 			= &clean_int($call_data{dnid}) ;
$call_data{call_did} 			= ($call_data{call_did} eq "") ? &clean_int($call_data{extension}) : $call_data{call_did} ;
$call_data{call_did} 			= (length($call_data{call_did}) eq 10) ? "1".$call_data{call_did} : $call_data{call_did};
$call_data{call_ani} 			= &clean_int($call_data{callerid});
$call_data{call_ani} 			= (length($call_data{call_ani}) eq 10) ? "1".$call_data{call_ani} : $call_data{call_ani};
$call_data{call_dst}			= "";
$call_data{call_uniqueid}		= &clean_str($call_data{uniqueid},"-.");
$call_data{call_channel}		= &clean_str($call_data{channel},"-./@;");

if  ($call_data{call_uniqueid} eq "") {my @mychars=('A'..'Z','a'..'z','0'..'9');$tmp = "";foreach (1..10) {$tmp .= $mychars[rand @mychars];}$call_data{call_uniqueid} = $call_data{system_host} .".". time .".". $tmp;}
$asterisk_debug_switch_screen 	= 1;
$asterisk_debug_switch_file		= 0;
#======================================================



#======================================================
# MAIN LOOP
#======================================================
&asterisk_debug_print("========================================================");
&asterisk_debug_print("$call_data{system_agi}  (START)");
&asterisk_debug_print("========================================================");
&asterisk_debug_print("system_host = $call_data{system_host}");
&asterisk_debug_print("system_agi  = $call_data{system_agi}");
&asterisk_debug_print("system_pid  = $call_data{system_pid}");
&asterisk_debug_print("uniqueid    = $call_data{call_uniqueid}");
&asterisk_debug_print("ani         = $call_data{call_ani}");
&asterisk_debug_print("did         = $call_data{call_did}");
&asterisk_debug_print("channel     = $call_data{call_channel}");

if ($call_data{arg_action} eq 'outbound_hangup') {
    $billsec = &asterisk_get_variable('CDR(billsec)');
    $recordingfile = &asterisk_get_variable('wrecordingfile');
    $destination = &asterisk_get_variable('wdestination');
    $tid = &asterisk_get_variable('ticketid');
    
    if (!$tid) {
        &asterisk_debug_print("no ticket id provided, exit!");
         exit 0;
    }
    
    $fileurl = "http://" . $ini->{default}{recording_path} . "/outbound/$recordingfile";
    
    $file = "/var/spool/asterisk/monitor/whmcs/$recordingfile";
    
    &asterisk_debug_print("add_sdpapi_note with parameters:$tid, $destination, $billsec, $fileurl, $file\n");

    &add_sdpapi_note($tid, $destination, $billsec, $fileurl, $file);
    exit 0;
}
if ($call_data{arg_action} eq 'inbound_hangup') {
    $billsec = &asterisk_get_variable('CDR(billsec)');
    $recordingfile = &asterisk_get_variable('wrecordingfile');
    $destination =  $call_data{call_ani};
    $tid = &asterisk_get_variable('ticketid');
    if (!$tid) {
         &asterisk_debug_print("no ticket id provided, exit!");
         exit 0;
    }
    
    $file = "/var/spool/asterisk/monitor/whmcs/$recordingfile";
    
    $fileurl = "http://" . $ini->{default}{recording_path} . "/outbound/$recordingfile";
    
    $file = "/var/spool/asterisk/monitor/whmcs/$recordingfile";
    
    &asterisk_debug_print("add_sdpapi_note with parameters:$tid, $destination, $billsec, $fileurl, $file\n");

    &add_sdpapi_note($tid, $destination, $billsec, $fileurl, $file);
    exit 0;
}

$call_data{call_did} = $call_data{call_did}."          ";
$call_data{channel_id}		= &clean_int(substr($call_data{call_did},4,100));
$call_data{channel_found}	= 0;
$AGI->answer();

local $annoncement_text = &check_whmcs_annoncement();
if (!$annoncement_text) {
    &asterisk_play(&get_recording('whmcs/ann'));
} else {
    asterisk_debug_print("announcement: $annoncement_text");
	&asterisk_play_text($annoncement_text);
}

local $d = &asterisk_loop_collect_digits(&get_recording('whmcs/ask_issue'), 1, 1, '12');

if ($d == 1) {
    goto STEP_NEWTICKET;
} elsif ($d == 2) {
    goto STEP_ENTERTICKET;
}

STEP_ENTERTICKET:
local $tid = &asterisk_loop_collect_digits(&get_recording('whmcs/enter_ticketnumber'), 10, 3);

STEP_REENTERTICKET:
&asterisk_debug_print("ticketid     = $tid");

if (!&check_sdpapi_ticket($tid)) {
    $tid = &asterisk_loop_collect_digits(&get_recording('whmcs/enter_wrong_ticketnumber'), 10, 3);
	if ($tid eq '0') {
        goto OPERATOR;
    } elsif ($tid eq '9') {
        goto STEP_NEWTICKET;
    } else {    
        goto STEP_REENTERTICKET;
    }
} else {
    goto TICKETNOTE;   
}


STEP_NEWTICKET:
&asterisk_play(&get_recording('whmcs/your_number'));
&asterisk_play_digits($call_data{call_ani});

local $tmp = &asterisk_loop_collect_digits(&get_recording('whmcs/check_mobile'), 10, 3);
&asterisk_debug_print("tmp mobile     = $tmp");
if ($tmp eq '1') {
    $mobile = $call_data{call_ani};
} else {
    while (1) {    
        if (!$tmp) {
            $tmp = &asterisk_loop_collect_digits(&get_recording('whmcs/input_mobile'), 10, 3);
        }
        
     
        &asterisk_play(&get_recording('whmcs/mobile_input'));
        &asterisk_play_digits($tmp);
        $d = &asterisk_loop_collect_digits(&get_recording('whmcs/confirm_mobile'), 1, 1, '12');
    
        if ($d eq '2') {
            $tmp = '';    
            next;
        } elsif ($d eq '1') {
            if (length($tmp) == 10) {
                $tmp = "1$tmp";
            }
            
            $mobile = $tmp;
            $tmp = '';
           last;
        } else {
            &asterisk_hangup;
            exit;
        }
    }
}

$sms_wait_seconds = 3;
STEP_SENDSMS:
$result = &asterisk_send_sms($mobile, 'Please Reply Back with Your email address');
&asterisk_debug_print("sms response = $result");

&asterisk_play(&get_recording('whmcs/send_sms'));

$i = 2;
STEP_CHECKINCOMINGSMS:

sleep $sms_wait_seconds;

$AGI->set_music('on', 'default');
$email = &asterisk_check_incomingsms($mobile);
$AGI->set_music('off');
if (!$email) {    
    $d = &asterisk_loop_collect_digits(&get_recording('whmcs/sms_notreceived'), 1, 1, '12');
    if ($d eq '1') {
        sleep 40;
        goto STEP_CHECKINCOMINGSMS;
    } else {
        if ($i-- <= 1) {
            goto OPERATOR;
        }
        
        $sms_wait_seconds = 3;
        goto STEP_CHECKINCOMINGSMS;
    }
    
}
&asterisk_debug_print("sms body = $email");


RECORDISSUE:
&asterisk_play(&get_recording('whmcs/say_issue'));
$filename =  time;
&asterisk_record("/var/lib/asterisk/wrecordings/$filename", 'wav');
$fileurl = "http://" . $ini->{default}{recording_path} . "/$filename.wav";

if ($ini->{default}{transcribe_enabled} eq 'true') {
	$AGI->set_music('on', 'default');
	$issue_text = &asterisk_recordingtotxt($fileurl);
	$AGI->set_music('off');
} else {
	$issue_text = 'transcribe not enabled!';
}



&asterisk_debug_print("transcribe: $issue_text");


$tid = &open_sdpapi_ticket($issue_text, $mobile, $email);

TICKETNOTE:
&asterisk_play(&get_recording("whmcs/ticket_number_is"));
&asterisk_play_digits($tid);
$billsec = &asterisk_get_variable('CDR(billsec)');
if ($filename) {
    $file =  "/var/lib/asterisk/wrecordings/$filename.wav";
}


=pod

$size = -s $file;
open R, $file;
sysread R, $data, $size;
close R;
&base64 = encode_base64($data);
=cut

&add_sdpapi_note($tid, $call_data{call_ani}, $billsec, $fileurl, $file);
&asterisk_play(&get_recording("whmcs/say_connect"));

OPERATOR:
&asterisk_play(&get_recording('whmcs/connect_operator'));

&asterisk_set_variable('__ticketid', $tid);

$extension_name = &check_sdpapi_ticket($tid);
$operator = '101';
if ($extension_name && $extension_name ne 'ok') {
	$operator = get_operator_extension($extension_name);
}
&asterisk_debug_print("operator for $extension_name: $operator");

&do_call($operator);

exit 0;



sub asterisk_debug_print(){
	my ($l) = @_;
	if ($asterisk_debug_switch_screen 	eq 1) { $AGI->verbose(&clean_str($l,"?&//\\/()-_+=:,[]><#*;"),1);	}
	#if ($asterisk_debug_switch_file 	eq 1) { print ASTERISK_DEBUG_FILEHANDLER time."|$l\n";		}
}

sub asterisk_dial(){
	my ($v1,$v2,$v3) = @_;
	return $AGI->exec('Dial', "$v1,$v2,$v3");
}

sub asterisk_hangup(){
	my ($v1,$v2,$v3) = @_;
	$AGI->hangup();
}

sub asterisk_play(){
	my ($audio,$stop_digits) =@_;
	my ($answer,$tmp,$tmp1,$tmp2);
	&asterisk_debug_print("ASTERISK PLAY ($audio) ($stop_digits)");
	$tmp = $AGI->stream_file($audio,$stop_digits);
	$tmp1 = chr($tmp);
	#&asterisk_debug_print("ASTERISK PLAY answer ($tmp) ($tmp1)");
	return &clean_str($tmp,"#");
}

sub asterisk_record(){
	my ($file,$extension) =@_;
	return $AGI->record_file($file,$extension,'#*', 120000, 0, 1, 3);
}

sub asterisk_talk(){
	my ($msg) =@_;
	return $AGI->exec('Festival', '"'.$msg.'"');
}

sub asterisk_collect_digits(){
	local($prompts_raw,$digits_limit)=@_;
	#local(@prompts,$prompts_qtd,$prompt,$play,$digits,$in_loop,$digits_code,$loop_count);
	$digits_limit++;
	$digits_limit--;
	$digits_limit = ($digits_limit<1) ? 100 : $digits_limit;
	$digits_limit = ($digits_limit>100) ? 100 : $digits_limit;
	my @prompts		= split(/\,/,$prompts_raw);
	my $prompts_qtd = @prompts;
	my $prompt		= "";
	my $play 		= ($prompts_qtd>0) ? 1 : 0;
	my $digits 		= "";
	my $in_loop 	= 1;
    my $digit_code 	= "";
    my $loop_count	= 0;
	while ($in_loop eq 1) {
		$loop_count++;
		if ($loop_count > 100) {
			$in_loop = 0;
		}
		if ($play eq 1) {
			$play = 0;
			foreach $prompt (@prompts) {
				$digit_code = $AGI->stream_file($prompt,"1234567890*#");
				if ($digit_code ne 0) {last}
			}
			if ($digit_code eq 0) {
				$digit_code = $AGI->wait_for_digit('5000');
			}
		} else {
			$digit_code = $AGI->wait_for_digit('5000');
		}
		
		&asterisk_debug_print("digit_code:$digit_code");

		my $digit = chr($digit_code);
		$digit = '*' if $digit_code == 42;
		if ($digit eq "#") {
			$in_loop = 0;
			if ($digits eq "") {$digits = "#"}
		} elsif ($digit_code eq 0) {
			$in_loop = 0;
		} else {
			$digits .= $digit;
		}
		if (length($digits) >= $digits_limit) {
			$in_loop = 0;
		}
	}
	return &clean_str($digits,"*#");
}
sub asterisk_collect_digit(){
	local($prompt,$flags)=@_;
	local($tmp,$digit,$digit_code,$tmp);
	$digit = "";
	if ($prompt ne "") {
		$digit_code = $AGI->stream_file($prompt,"$flags");
		$digit = chr($digit_code);
	}
	if ( ($digit_code eq 0) && (index("\L,$flags,",",no-wait,") eq -1) ) { 
		$tmp = 5000;
		$tmp = (index("\L,$flags,",",wait1sec,") ne -1) ? 1000 : $tmp;
		$tmp = (index("\L,$flags,",",wait2sec,") ne -1) ? 2000 : $tmp;
		$digit_code = $AGI->wait_for_digit($tmp);
		$digit = chr($digit_code);
	}
	return &clean_str($digit,"*#");
}

sub asterisk_play_digits(){
	my ($msg) =@_;
	return $AGI->say_digits($msg);
}

sub asterisk_play_number(){
	my ($msg) =@_;
	return $AGI->say_number($msg);
}

sub asterisk_status() {
	return $AGI->exec('CHANNEL STATUS', '"'.$msg.'"');
}

sub asterisk_status_is_active() {
	local($tmp);
	$tmp = $AGI->stream_file("silence");
	return ($tmp eq 0) ? 1 : 0;
}

sub asterisk_play_dial_number();

sub asterisk_count_active_ani() {
	local($ani_to_search) = @_;
	local($ani_count,$tmp,%ids,$id,$peername,$callid);
	$ani_count = 0;
	$ani_to_search = substr($ani_to_search,1,1000);
	foreach (&asterisk_run_command("sip show channels")) {
		if(index($_,".") eq -1) {next}
		if(index($_,"$ani_to_search") eq -1) {next}
		$tmp=substr($_,29,11);
		$ids{$tmp}++;
	}
	foreach $id (sort keys %ids){
		$peername = "";
		$callid = "";
		foreach (&asterisk_run_command("sip show channel $id")) {
			if (index($_,"Peername:") ne -1){
				$peername = substr($_,25,1000);
			}
			if (index($_,"Caller-ID:") ne -1){
				$callid = substr($_,25,1000);
			}
		}
		if (index($peername,"RNK-01") ne -1){
			if (index($callid,"$ani_to_search") ne -1){
				$ani_count++;
			}
		}
	}
	return $ani_count;
}

sub asterisk_run_command(){
	local($cmd) = @_;
	local(@out,@list,$l);
	@list = `asterisk -r -x "$cmd"`;
	foreach $l (@list) {
		chomp($l);
		@out=(@out,$l);
	}
	return @out;
}

sub asterisk_set_variable(){
	($name,$value) = @_;
	$AGI->set_variable($name,$value);
}

sub asterisk_get_variable(){
	($name) = @_;
	return $AGI->get_variable($name);
}

sub asterisk_loop_collect_digits() {
    local ($prompt, $len, $loop, $sets) = @_;
    $len  ||= 1;
    $loop ||= 1;
    local $d;
    
	&asterisk_debug_print("$prompt, $len, $loop, .");

    if ($len < 2) {
        for (1..$loop) {
            $d = &asterisk_collect_digit($prompt, '1234567890*#');
			&asterisk_debug_print("d     = $d.");

            last if ($d || $d eq '0') && (index("$sets", $d) != -1);
        }
    } else {
        for (1..$loop) {
            $d = &asterisk_collect_digits($prompt, $len);
            last if ($d || $d eq '0');
        }
    }
    
    return $d;    
}

sub asterisk_play_text() {
	local ($txt)   = @_;
	local $tmpfile = "/tmp/" . time . '-' . (int rand 9999);
	
    local $polly = Paws->service('Polly',  region => $aws_region,
        credentials => Paws::Credential::File->new(
            profile => 'default',
            credentials_file => '/etc/aws.cfg', 
        )
    );
	#Aditi,Amy,Astrid,Bianca,Brian,Camila,Carla,Carmen,Celine,Chantal,Conchita,Cristiano,Dora,Emma,Enrique,Ewa,Filiz,Geraint,Giorgio,Gwyneth,Hans,Ines,Ivy,Jacek,Jan,Joanna,Joey,Justin,Karl,Kendra,Kimberly,Lea,Liv,Lotte,Lucia,Lupe,Mads,Maja,Marlene,Mathieu,Matthew,Maxim,Mia,Miguel,Mizuki,Naja,Nicole,Penelope,Raveena,Ricardo,Ruben,Russell,Salli,Seoyeon,Takumi,Tatyana,Vicki,Vitoria,Zeina,Zhiyu
	$voiceid = $ini->{default}{tts_voiceid} || 'Amy';
    local $data = $polly->SynthesizeSpeech('OutputFormat' => 'mp3', 'Text' => $txt, 'VoiceId' => $voiceid);
    
    open M, "> $tmpfile.mp3";
    print M $data->AudioStream;
	close M;
    #system("mp3gain -r -d 1 $tmpfile.mp3");
	system("ffmpeg -i $tmpfile.mp3 -ar 8000 -ac 1 $tmpfile.wav");
	unlink "$tmpfile.mp3";

	&asterisk_play($tmpfile);
	unlink "$tmpfile.wav";
}

sub asterisk_play_text2() {
	local ($txt)   = @_;
	local $tmpfile = "/tmp/" . time . '-' . (int rand 9999);
	warn $tmpfile;
	
	system("curl -o $tmpfile.wav -d \"q=EN$txt\" -k 'http://tts-host/api/tts-google.pl'");
	&asterisk_play($tmpfile);
	
	unlink "$tmpfile.wav";
}

sub check_whmcs_annoncement () {
	local $query = 'action=getannouncements';
	return;
	local %response = &send_request($query);
	
	local $total = $response{totalresults};
	
    if (!$total && -e "/tmp/WHMCSTEST") {
        return "We are very sorry! Our provider is down, it will recover in about 10 minutes"
    }
	return if !$total;
	
    
	local $title = $response{announcements}{announcement}[0]{announcement};
    if ($title eq '(null)') {
        return;
    }
    
    
	return 	$title;
}

sub check_whmcs_clientid () {
	local ($clientid) = @_;
	local $query = 'action=getclients';
	local %response = &send_request($query);
	
	local $total = $response{totalresults};
	
	return if !$total;
	
	for (@{$response{clients}{client}}) {
		#warn "compare " . $_->{id} . "== $clientid";
		return 1 if $_->{id} == $clientid;
	}
	
	return ;
}

sub check_sdpapi_ticket () {
	local ($tid) = @_;
	local $query = "request/$tid";
	
	local %response = &send_sdpapi_request($query, '');
	
	if ($response{operation}{result}{status} ne 'Success') {
		return;
	}
	
	return $response{operation}{details}{technician_loginname} || 'ok';
}

sub check_whcms_ticket () {
	local ($tid) = @_;
	local $query = "action=getticket&ticketid=$tid";
	
	local %response = &send_request($query);
	
	if ($response{result} eq 'error') {
		return;
	}
	
	return 1;
}

sub open_whmcs_ticket () {
	local ($message, $cid, $email) = @_;
    $message = uri_escape($message);
	local $query = "action=openticket&deptid=2&subject=ticketbyphone&message=$message&name=$cid&email=$email";
	
	
	local %response = &send_request($query);
	
	if ($response{result} eq 'error') {
		return;
	}
	
	return $response{tid};
}

sub open_sdpapi_ticket () {
	local ($message, $cid, $email) = @_;
    #$message = uri_escape($message);
	
	$message =~ s/['"]/ /g;
    $message =~ s/\n/<br>/g;
	
    local %tmp = ();
    $tmp{operation}{details}{subject}  = "Request Added On Phone - " . substr($message, 0, 10);
    $tmp{operation}{details}{description}  = $message;
    $tmp{operation}{details}{requester}   = $cid;
    $tmp{operation}{details}{site}   = 'CFBTEL';
    $tmp{operation}{details}{account}   = 'CFBTEL';
        
    local %response = &send_sdpapi_request('request', &Hash2Json(%tmp));
	
	if ($response{operation}{result}{status} ne 'Success') {
		return;
	}
	
    return $response{operation}{details}{workorderid};
}

sub add_sdpapi_note () {
	local ($tid, $cid, $billsec, $recording_url, $file) = @_;
    $message = "CID: $cid<br>BILLSEC: $billsec";
    if ($fileurl) {
        $message .= "<br>Recording: <a href=$recording_url>$recording_url</a>";
    }
    
   
    #$message = uri_escape($message);
    $message =~ s/['"]/ /g;
	local $query = "action=AddTicketNote&ticketid=$tid&message=$message";
	
	local %tmp = ();
    $tmp{operation}{details}{notes}{note}{ispublic} = "true";
    $tmp{operation}{details}{notes}{note}{ispublic} = "true";
    $tmp{operation}{details}{notes}{note}{markFirstResponse} = "true";
    $tmp{operation}{details}{notes}{note}{notifytech} = "true";
    $tmp{operation}{details}{notes}{note}{addtolinkedrequest} = "true";
    
    $tmp{operation}{details}{notes}{note}{notestext} = $message;
    
	local %response = &send_sdpapi_request("request/$tid/notes", &Hash2Json(%tmp));
	
	if ($response{operation}{result}{status} ne 'Success') {
		return;
	}
	
    &send_sdpapi_request("request/$tid/attachments", "UPLOAD", $file);
	return 1;
}

sub add_whmcs_note () {
	local ($tid, $cid, $billsec, $recording_url) = @_;
    $message = "CID: $cid\nBILLSEC: $billsec\nRecording: $recording_url\n";
    $message = uri_escape($message);
	local $query = "action=AddTicketNote&ticketid=$tid&message=$message";
	
	
	local %response = &send_request($query);
	
	if ($response{result} eq 'error') {
		return;
	}
	
	return $response{tid};
}

sub do_call() {
    local ($ext) = @_;
	$AGI->set_context('from-internal');
	$AGI->set_extension($ext);
	$AGI->set_priority(1);
	
	return 1;
}
sub do_call2() {
	local ($ext) = @_;
	use Cache::Memcached;
	my $memcache = "";
    my $memcache = new Cache::Memcached {'servers' => ['127.0.0.1:11211']};
	local %hash = (ticketid => $tid, callerid => $call_data{call_ani}, 'starttime' => time);
	local $json = &Hash2Json(%hash);

	$memcache->set($call_data{call_channel}, $json, 600);
	$json = $memcache->get($call_data{call_channel});
	&asterisk_debug_print("set the ticket of $call_data{channel}  to $json");

	$AGI->set_context('from-internal');
	$AGI->set_extension($ext);
	$AGI->set_priority(1);
	
	return 1;
}

sub send_request () {
	local ($query) = @_;
	
	$AGI->set_music('on', 'default');
	$url = "http://member.cfbtel.com/includes/api.php?username=" . $ini->{default}{whmcs_api_username} .
          "&password=" . $ini->{default}{whmcs_api_password} . "&responsetype=json&$query";
	
	&asterisk_debug_print("apiurl     = $url");

	local $out = `curl -k '$url'`;
	
	#&asterisk_debug_print("$response     = $out");

	local %hash = &Json2Hash($out);
	
	$AGI->set_music('off');
					
	return %hash;
}

sub send_sdpapi_request () {
	local ($query, $data, $file) = @_;
	
	$AGI->set_music('on', 'default');
	$url = "http://help.cfbtel.com/sdpapi/auth/?username=" . $ini->{default}{sdpapi_user} . "&password=" . $ini->{default}{sdpapi_password} . "&format=json";
	
	&asterisk_debug_print("apiurl     = $url");

	local $out = `curl -k '$url'`;
	
	#&asterisk_debug_print("$response     = $out");

	local %hash = &Json2Hash($out);
	
    if ($hash{operation}{result}{status} ne 'Success') {
        &asterisk_debug_print("Error: fail to login sdpapi");
        return;
    }
    
     if ($data eq 'UPLOAD' && $file) {
        $data = "-F 'AUTHTOKEN=". $hash{operation}{details}{techniciankey} . "' -F 'OPERATION_NAME=UPLOAD' -F 'format=json' " .
                " -F 'attachment=\@$file'";
        #print "upload data: $data\n";
        $url = "http://help.cfbtel.com/sdpapi/$query";
        #print "curl -k '$url'  $data";
        $out = `curl -k '$url'  $data`;
    } else {
        
        $url = "http://help.cfbtel.com/sdpapi/$query?format=json&AUTHTOKEN=" . $hash{operation}{details}{techniciankey};
        &asterisk_debug_print("$url : $data");
        if ($data) {
            $out = `curl -k '$url' -X POST --data 'data=$data'`;                  
        } else {
            $out = `curl -k '$url'`;
        }
    }
     
	$AGI->set_music('off');
	%hash = &Json2Hash($out);		
	return %hash;
}

sub asterisk_send_sms() {
    local ($mobile, $body) = @_;
    my $twilio = new WWW::Twilio::API( AccountSid => $ini->{default}{twilio_account_sid},
                                    AuthToken  => $ini->{default}{twilio_auth_token} );
    $response = $twilio->POST('SMS/Messages',
                From =>  $ini->{default}{twilio_sms_number},
                To   => "+$mobile",
                Body => $body );
    
    return $response;
}


sub asterisk_check_incomingsms() {
    local ($mobile) = @_;
    $to = $ini->{default}{twilio_sms_number};
    $mobile =~ s/\+//g;
    $to =~ s/\+//g;
    $file = "/var/www/html/sms/$mobile-$to.sms";
    for (1 .. 30) {
        &asterisk_debug_print("check $file ...");

        if (-e $file) {
            $size = -s $file;
            open W, $file;
            sysread W, $data, $size;
            close W;
            unlink $file;
            last;
        }
        
        sleep 2;
    }
   
    
    return $data;
    
}

sub asterisk_recordingtotxt () {
	local ($fileurl) = @_;
	return ' ' unless $fileurl;	
	&asterisk_debug_print("fileurl: $fileurl");

	$access_token = $ini->{default}{voicebase_access_token};
	$cmd = "curl -X POST -k -s  https://apis.voicebase.com/v3/media --header \"Authorization: Bearer $access_token\" --form mediaUrl=$fileurl";
	#warn $cmd;
	$result = `$cmd`;
	
	%hash = &Json2Hash($result);
	#warn $result;
	if ($hash{status} eq 'accepted') {
		$media_id = $hash{mediaId};
        &asterisk_debug_print("media_id: $hash{mediaId}");
	} else {
		&asterisk_debug_print("Error: $hash{errors}");
		return;
	}
	
    
	for (1..60) {
		$cmd = "curl -s https://apis.voicebase.com/v3/media/$media_id  --header \"Authorization: Bearer $access_token\"";
		#warn $cmd, "\n\n";
		$result = `$cmd`;
		#			warn $result, "\n\n";

		%hash = &Json2Hash($result);
		if ($hash{status} ne 'finished') {
		#	warn $hash{media}{status}, "\n";
            &asterisk_debug_print("media_id: $media_id - $hash{status}, transcribe not done, sleep 2 seconds");
			sleep 2;
		} else {
			last;
		}
	}
	
	if ($hash{status} ne 'finished') {
		&asterisk_debug_print("Error: fail to get transcribe for $media_id in 2 minutes!");
		return;
	}
	
	$cmd = "curl -s https://apis.voicebase.com/v3/media/$media_id/transcript/text --header 'Accept: text/plain' --header \"Authorization: Bearer $access_token\"";
	#warn $cmd;
	$result = `$cmd`;
	return $result;
}
sub get_operator_extension {
	local $name = shift || return '';
	
	local %hash = &database_select_as_hash("select 1,extension from users where name='$name' limit 1", "extension");
	
	return $hash{1}{extension};
}

sub get_recording {
	$fn = shift;
	($n) = $fn =~ m{.+/(\w+)};
	if ($recording_ini->{default}{$n}) {
		($t, $s, $v) = split /\|\|/, $recording_ini->{default}{$n}, 3;
		if ($t eq 'system') {
			return $s;
		}
	}
	
	#&asterisk_debug_print("$fn: $n");
	return $fn;	
}

1;
