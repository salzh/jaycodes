use Paws::Credential::File;
use Paws::Transcribe::Media;
use Paws;
use Data::Dumper;
use JSON; # to install, # sudo cpan JSON
use LWP::Simple;
use WWW::Twilio::API;
use URI::Escape;
$json_engine	= JSON->new->allow_nonref;

$config_file = "/etc/aws.cfg";
$bucketname = 'backuprecordings';
$file = "/root/hello.mp3";
$aws_region = 'us-west-2';

$ini = Config::INI::Reader->read_file($config_file);

=pod
my $obj = Paws->service('Polly',  region => 'us-east-2',
    credentials => Paws::Credential::File->new(
        profile => 'default',
        credentials_file => $config_file, 
      )
);
$result = $obj->DescribeVoices();
#print Data::Dumper::Dumper($result);
$data = $obj->SynthesizeSpeech('OutputFormat' => 'mp3', 'Text' => 'hello world', 'VoiceId' => 'Amy');
open M, "> hello.mp3";
print M $data->AudioStream;
close M;

my $twilio = new WWW::Twilio::API( AccountSid => $ini->{default}{twilio_account_sid},
                                    AuthToken  => $ini->{default}{twilio_auth_token} );
$response = $twilio->POST('SMS/Messages',
            From => '+12053950249',
            To   => '+19803892888',
            Body => "Hey, let's have lunch" );
#&d($response);
=cut

#print "check ticket: " . &check_sdpapi_ticket('18481') . "\n";

print "add note: " . &add_sdpapi_note('18481', '18882115404', '60', 'http://jaypbx.cfbtel.com', '/salzh/code/ivr/sounds/whmcs/ann.wav'). "\n";
#print "add ticket:" . &open_sdpapi_ticket('my phones are all down', '18184885588', 'zhongxiang721@163.com'). "\n";
sub asterisk_transcribe() {
   
    $file = "/root/hello.mp3";
    $filename = "hello.mp3";
    $s = &upload_s3_file("/$bucketname/$filename", $file);
    if (!$s) {
        warn "Fail to upload $file to s3!\n";
        return;
    }
    
    $jobname = start_transcribe($filename);
    warn "$jobname is submitted!\n";
    
    while (1) {
        $obj = get_transcribe($jobname);
        $status = $obj->TranscriptionJob->TranscriptionJobStatus;
        if ( $status eq 'COMPLETED') {
            last;
        }
        warn "Job still $status ...\n";
        sleep 1;
    }
    
    $s3_uri = $obj->TranscriptionJob->Transcript->TranscriptFileUri;
    #warn $s3_uri;
    $json = get($s3_uri);
    %hash = &Json2Hash($json);
    print $hash{results}{transcripts}[0]{transcript};
}

sub get_transcribe() {
    $name = shift;
    
     my $obj = Paws->service('Transcribe',  region => $aws_region,
        credentials => Paws::Credential::File->new(
            profile => 'default',
            credentials_file => $config_file, 
          )
    );
    
    $response = $obj->GetTranscriptionJob(TranscriptionJobName => $name);
    #&d($response);
    return $response;
}


sub start_transcribe() {
    $filename = shift;
    my $obj = Paws->service('Transcribe',  region => $aws_region,
        credentials => Paws::Credential::File->new(
            profile => 'default',
            credentials_file => $config_file, 
          )
    );
    
    $tname =  time . '-' . (int rand 9999);
    $response = $obj->StartTranscriptionJob(LanguageCode => 'en-US', TranscriptionJobName => $tname,
                                Media  => Paws::Transcribe::Media->new('MediaFileUri' => "https://s3-us-west-2.amazonaws.com/$bucketname/$filename"));
    &d($response);
    
    return $tname;
}


sub d() {
    $obj = shift;
    
    print Data::Dumper::Dumper($obj);
}

sub upload_s3_file () {
	local ($url, $file) = @_;
	require Net::Amazon::S3;

	
	$ini = Config::INI::Reader->read_file($config_file);
	#warn "$access_key, $secret_key";
	$s3 = Net::Amazon::S3->new({aws_access_key_id     => $ini->{default}{aws_access_key_id},
								aws_secret_access_key => $ini->{default}{aws_secret_access_key},
								retry                 => 1,
								}
							);
							
	
	if (!$s3) {
		return
	}
	
	($bucketname, $key) = $url =~ m{^/(.+?)/(.+)$};
	
	warn "$bucketname, $key, $url";
	$bucket = $s3->bucket($bucketname);
	
	if ($key =~ /pdf$/i) {
		$type = 'application/pdf';
	} elsif ($key =~ /tif$/i) {
		$type = 'image/tiff';
	} elsif ($key =~ /jpeg$/i) {
		$type = 'image/jpeg';
	} else {
		$type = 'binary/octet-stream';
	}
	
	return $bucket->add_key_filename($key, $file, {content_type => $type});
}

sub check_sdpapi_ticket () {
	local ($tid) = @_;
	local $query = "request/$tid";
	
	local %response = &send_sdpapi_request($query, '');
	
	if ($response{operation}{result}{status} ne 'Success') {
		return;
	}
	
	return 1;
}

sub open_sdpapi_ticket () {
	local ($message, $cid, $email) = @_;
    $message = uri_escape($message);
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

sub send_sdpapi_request () {
	local ($query, $data, $file) = @_;
	
	#$AGI->set_music('on', 'tech');
	$url = "http://help.cfbtel.com/sdpapi/auth/?username=" . $ini->{default}{sdpapi_user} . "&password=" . $ini->{default}{sdpapi_password} . "&format=json";
	
	#&asterisk_debug_print("apiurl     = $url");

	local $out = `curl -k '$url'`;
	
	#&asterisk_debug_print("$response     = $out");

	local %hash = &Json2Hash($out);
	
    if ($hash{operation}{result}{status} ne 'Success') {
        #&asterisk_debug_print("Error: fail to login sdpapi");
        return;
    }
    
    if ($data eq 'UPLOAD' && $file) {
        $data = "-F 'AUTHTOKEN=". $hash{operation}{details}{techniciankey} . "' -F 'OPERATION_NAME=UPLOAD' -F 'format=json' " .
                " -F 'attachment=\@$file'";
        print "upload data: $data\n";
        $url = "http://help.cfbtel.com/sdpapi/$query";
        print "curl -k '$url'  $data";
        $out = `curl -k '$url'  $data`;
    } else {
        
        $url = "http://help.cfbtel.com/sdpapi/$query?format=json&AUTHTOKEN=" . $hash{operation}{details}{techniciankey};
        print $url, "\n $data\n";
        if ($data) {
            $out = `curl -k '$url' -X POST --data 'data=$data'`;                  
        }
    }
    print "$out\n";
     %hash = &Json2Hash($out); 
	#$AGI->set_music('off');
					
	return %hash;
}

sub Json2Hash(){
	local($json_plain) = @_;
	local(%json_data);
	my %json_data = ();
	if ($json_plain ne "") {
		local $@;
		eval {
			$json_data_reference	= $json_engine->decode($json_plain);
		};
		
		if ($@) {warn $@}
		%json_data			= %{$json_data_reference};
	}
	return %json_data;
}
sub Hash2Json(){
	local(%jason_data) = @_;
	# hack: error.code need be a numeric if value is 0
	#if ( exists($jason_data{error}) ){
	#	if ($jason_data{error}{code} == "0"){
	#		$jason_data{error}{code} = 0;
	#	}
	#}
	my $json_data_reference = \%jason_data;
	my $json_data_text		= $json_engine->encode($json_data_reference);
	return $json_data_text;
}