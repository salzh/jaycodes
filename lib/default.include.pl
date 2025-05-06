#!/usr/bin/perl
################################################################################
#
# global libs for AGI, perl scripts and CGI
# extra libs for multilevel services  
# developed for years to zenofon
#
################################################################################
$|=1;$!=1; # disable buffer 
use File::Copy;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use DBI;
use LWP 5.69;
use Asterisk::AMI;
use Data::Dumper;
use Carp; $SIG{ __DIE__ } = sub { Carp::confess( @_ ) };
$app_root							= "/salzh/codes/";
%template_buffer					= ();
$database 							= null;
$conection 							= null;
$database_connected					= 0;
$database_last_error				= "";
# in future, move database settings to externalfile. 
# Use hardcode make life complex to manage production and multiple development base
# all other data need leave in database
$database_dsn						= "dbi:mysql:asterisk:localhost:3306";
$database_user						= "freepbxuser";
$database_password					= "F+vB7DS5kCAL";
$asterisk_manager_is_connected		= 0;
$asterisk_manager_connection		= null;
$asterisk_manager_response			= null;
$asterisk_manager_ip				= "127.0.0.1";
$asterisk_manager_port				= "5038";
$asterisk_manager_user				= "admin";
$asterisk_manager_secret			= "p3cMWCPNOFC4";
$im_identify						= "/usr/bin/identify";
$im_convert							= "/usr/bin/convert";
$im_composite						= "/usr/bin/composite";

%app						= ();

use JSON; # to install, # sudo cpan JSON
$json_engine	= JSON->new->allow_nonref;

&default_include_init();
return 1;
#=======================================================



sub default_include_init(){
	open(IN,"/etc/cfb.cfg"); while (<IN>) { chomp($_); ($tmp1,$tmp2) = split(/\=/,$_,2); $app{&trim("\L$tmp1")}=$tmp2; } close(IN);
	$app{app_root}			= $app{app_root} || "/usr/local/pbx-v2/";
	##$app{host_name}			= $app{host_name} || "dev-desktop";# we need remove all calls to this variable. we need use server_id instead
	$app{server_id}			= $app{server_id} || "1";
	$app{database_dsn}		= $app{database_dsn} || "dbi:mysql:asterisk:localhost";
	$app{database_user}		= $app{database_user} || "freepbxuser";
	$app{database_password}	= $app{database_password} || "F+vB7DS5kCAL";
	
	$app{log_file}		= '/tmp/pbx.log';
	open LOG, ">> $app{log_file}";

}

#=======================================================
# radio_data_client lib
#=======================================================
# This help to get/set data from clients.
# we have 3 client data levels.
# - First level its data that belong to THIS client, like name, email, username, password etc etc. You just need inform client_id
# - Second is client data in ONE station. Things like tags statistics. You need inform client_id and station_id
# - 3rd is client data in ONE channel. Things like permissions, statistics. You need inform client_id and channel_id
#
# tables:
# we create new tables for this new client structure, but we also need change radio_log_session table
# ALTER TABLE `owsline`.`radio_log_session` ADD COLUMN `radio_data_client_id` BIGINT UNSIGNED AFTER `digits`;
#




#------------------------
# appkonference lib 
#------------------------
sub app_konference_channel_stream_connect(){
	local($host,$channel_id) = @_;
	local($response,%action,$tmp);
	$response = &RemoteAsterisk($host,"/konference_stream_connect/?stream_server_ip=$hardcoded_stream_server_ip&conference_id=$channel_id");
	return $response;
}
sub app_konference_channel_stream_disconnect(){
	local($host,$channel_id) = @_;
	local(%conference,$response,%action,$tmp);
	$response = &RemoteAsterisk($host,"/konference_stream_disconnect/?conference_id=$channel_id");
	return $response;
}

sub app_konference_channel_recording_connect(){
	local($host,$channel_id) = @_;
	local($response,%action,$tmp);
	$response = &RemoteAsterisk($host, "/konference_recording_connect/?stream_server_ip=$hardcoded_stream_server_ip&conference_id=$channel_id");
	return $response;
}
sub app_konference_channel_recording_disconnect(){
	local($host,$channel_id) = @_;
	local(%conference,$response,%action,$tmp);
	$response = &RemoteAsterisk($host, "/konference_recording_disconnect/?conference_id=$channel_id");
	return $response;
}

sub app_konference_list_summary(){
	#
	# Notes: All other app_konference_* calls will be only called by webservice and 
	# are just a mask to access api over web at :171 port
	# only app_konference_list_summary and app_konference_list will be used in both sides
	# (at web and also at call/stream services) so we have a magic host LOCAL that will
	# query local asterisk instead go to web api (and save one web access overhead)
	#
	local ($host) = @_;	
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	local (@hosts,$line);
	$host = substr(&clean_str($host,"MINIMAL"),0,100);
	%data = ();
	if ($host eq "LOCAL") {
		@answer = &asterisk_manager_command_simple_as_array("konference list");
	} else {
		@answer = &RemoteAsterisk_AsArray($host,"/konference_list");
	}
	foreach $line (@answer){
		# 0.........1.........2.........3.........4.........5.........6.........7.........8.........9.........10........11........12........13........14.........
		# 0123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
		# Name                 Members              Volume               Duration            
		# 21908                2                    0                    00:00:10
		$v1 = &trim(substr($line,0,18));
		if ($v1 ne &clean_int($v1)) {next}
		$v2 = &trim(substr($line,21,18));
		if (substr($v1,-1,1) eq "P") {
			$conference = &clean_int($v1);
			$qtd = $v2;
			$qtd++; $qtd--;
		} else {
			$conference = $v1;
			$qtd = $v2;
			$qtd--;
			$qtd = ($qtd < 0) ? 0 : $qtd;
		}
		$data{by_host}{$host}{qtd_total} += $qtd;
		$data{by_conference}{$conference}{qtd_total} += $qtd;
		$data{by_host_and_conference}{$host}{$conference}{qtd_total} += $qtd;
		$data{qtd_total} += $qtd;
	}
	return %data;
}
sub app_konference_list(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$conference_name) = @_;	
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	local ($line);
	$conference_name = substr(&clean_str($conference_name,"MINIMAL"),0,100);
	%data = ();
	if ($host eq "LOCAL") {
		@answer = &asterisk_manager_command_simple_as_array("konference list $conference_name ");
	} else {
		@answer = &RemoteAsterisk_AsArray($host,"/konference_list/?conference_id=$conference_name");
	}
	foreach $line (@answer){
		#$data{debug}{raw_lines} .= $line;
		# 0.........1.........2.........3.........4.........5.........6.........7.........8.........9.........10........11........12........13........14.........
		# 0123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.123456789.
		# User #               Flags                Audio                Volume               Duration             Spy                  Channel                                                                         
		# 1                    qLR-105721           Muted                0:0                  00:00:05             *                    SIP/112233-00000003    
		# ---------------
		# read line
		# ---------------
		$v1 = &trim(substr($line,0,18));
		if ($v1 ne &clean_int($v1)) {next}
		$v2 = &trim(substr($line,21,18));
		$v3 = &trim(substr($line,42,18));
		$v4 = &trim(substr($line,63,18));
		$v5 = &trim(substr($line,84,18));
		$v6 = &trim(substr($line,105,18));
		$v7 = &trim(substr($line,126,100));
		if($v2 eq "Flags") {next}
		# ---------------
		# basic data
		# ---------------		
		($tmp1,$tmp2,$tmp3) = split(/\:/,$v5);
		$tmp1++; $tmp2++; $tmp3++;
		$tmp1--; $tmp2--; $tmp3--;
		$data{$v1}{duration_seconds}			= $tmp3+($tmp2*60)+($tmp1*3600);
		$data{$v1}{flags} 						= $v2;
		$data{$v1}{muted} 						= ($v3 eq "Muted") ? 1 : 0;
		$data{$v1}{duration} 					= $v5;
		$data{$v1}{conference_name} 			= $conference_name;
		$data{$v1}{user} 						= $v1;
		$data{$v1}{sip_channel} 				= $v7;
		$data{$v1}{volume_talk} 				= (split(/\:/,$v4))[0];
		$data{$v1}{volume_listen} 				= (split(/\:/,$v4))[1];
		$data{$v1}{type} 						= "UNKNOWN";
		$data{$v1}{radio_log_session_id_hex}	= "";
		$data{$v1}{radio_log_session_id}		= "";
		if  (index($v2,"LR") eq 0) {
			$data{$v1}{type} 						= "LISTENER";			
			$data{$v1}{radio_log_session_id_hex} 	= substr($v2,2,100);
			$data{$v1}{radio_log_session_id} 		= hex($data{$v1}{radio_log_session_id_hex});
		} elsif  (index($v2,"R") eq 0) {
			$data{$v1}{type} 						= "TALKER";			
			$data{$v1}{radio_log_session_id_hex} 	= substr($v2,1,100);
			$data{$v1}{radio_log_session_id} 		= hex($data{$v1}{radio_log_session_id_hex});
		} elsif  (index($v2,"Ccl") eq 0) {
			$data{$v1}{type} = "STREAM";			
		} elsif  (index($v2,"CcL") eq 0) {
			$data{$v1}{type} = "RECORDING";
		}
		# ---------------
		# extra data
		# ---------------		
		if ($data{$v1}{radio_log_session_id} ne "") {
	    	%hash = database_select_as_hash("SELECT 1,1,id,ani,did,radio_data_client_id,radio_data_station_id,radio_data_station_channel_id,poll_votes_count,poll_last_vote_value FROM radio_log_session where id='$data{$v1}{radio_log_session_id}'","flag,log_id,ani,did,client_id,station_id,channel_id,poll_votes_count,poll_last_vote_value");
		    if ($hash{1}{flag} eq 1) { 
		    	$data{$v1}{client_id}	= $hash{1}{client_id};
		    	$data{$v1}{client_id}	= $hash{1}{channel_id};
		    	$data{$v1}{station_id}	= $hash{1}{station_id};
		    	$data{$v1}{ani}			= $hash{1}{ani};
				$data{$v1}{ani_format} 	= &clean_str(&format_dial_number($data{$v1}{ani}),"MINIMAL","()-+_");
		    	$data{$v1}{did}			= $hash{1}{did};
		    	$data{$v1}{last_vote}	= $hash{1}{poll_last_vote_value};
		    	$data{$v1}{votes_count}	= $hash{1}{poll_votes_count};
		    	if ($data{$v1}{client_id} ne "") {
					$data{$v1}{name}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"name");
					$data{$v1}{flag_0}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_0");
					$data{$v1}{flag_1}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_1");
					$data{$v1}{flag_2}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_2");
					$data{$v1}{flag_3}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_3");
					$data{$v1}{flag_4}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_4");
					$data{$v1}{flag_5}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_5");
					$data{$v1}{flag_6}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_6");
					$data{$v1}{flag_7}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_7");
					$data{$v1}{flag_8}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_8");
					$data{$v1}{flag_9}		= &radio_data_client_station_set($data{$v1}{client_id},$data{$v1}{station_id},"flag_9");
		    	}
		    }
		}	
	}
	return %data;
}
sub app_konference_listenervolume_down(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_listenervolume_down/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_listenervolume_up(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_listenervolume_up/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_talkvolume_down(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_talkvolume_down/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_talkvolume_up(){
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	&RemoteAsterisk($host,"/konference_talkvolume_up/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_kick(){
	#
	# kick one channel out of conference. Remember this is not hangup.
	# 
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel) = @_;
	# TODO: clean channel to avoid attack
	&RemoteAsterisk($host,"/konference_kick/?channel=".&cgi_url_encode($sip_channel));
}
sub app_konference_set_channel_mode(){
	#
	# change channel mode (listener/talker/private) for a specific active
	# channel at asterisk.
	#
	# All other api calls auto detect host, but this one we NEED specify host
	# Maybe we need change from host to channel_id and query
	# database to known call_host 
	#
	local ($host,$sip_channel,$mode) = @_;
	local (%data,$v1,$v2,$v3,$v4,$v5,$v6,$v7,$tmp,$tmp1,$tmp2,%hash);
	$tmp = "";
	$tmp = ($mode eq "0"		) ? "0"	: $tmp;
	$tmp = ($mode eq "1"		) ? "1"	: $tmp;
	$tmp = ($mode eq "2"		) ? "2"	: $tmp;
	$tmp = ($mode eq "TALKER"	) ? "1"	: $tmp;
	$tmp = ($mode eq "LISTENER"	) ? "0"	: $tmp;
	$tmp = ($mode eq "PRIVATE"	) ? "2"	: $tmp;
	if ($tmp eq "") {return 0;}
	&RemoteAsterisk($host,"/setvar/?name=conference_type&value=$tmp&channel=".&cgi_url_encode($sip_channel));
	&RemoteAsterisk($host,"/konference_kick/?channel=".&cgi_url_encode($sip_channel));
	if($mode eq "1" || $mode eq 'TALKER'  ) {
		&RemoteAsterisk($host,"/setvar/?name=istalked&value=1&channel=".&cgi_url_encode($sip_channel));
	}
}

sub app_konference_get_channel_istalked(){

	local ($host,$sip_channel) = @_;
	$res = &RemoteAsterisk($host,"/getvar/?name=istalked&channel=".&cgi_url_encode($sip_channel));
	
	return int($res);
}

#------------------------
#
#------------------------
# remote asterisk
#------------------------
# todo: inplement webservices with api in each asterisk and connect this api calls to webservices
# right now, remote is disabled, only query local asterisk 
sub DELETEME_remote_asterisk_command(){
	local ($host,$asterisk_cmd) = @_;
	local($cmd,@ans);
	# todo: clean cmd to avoid attack
	# todo: JUST LOCAL RIGHT NOW: in futue, implement webservice at remote asterisks and use remote services
	@ans = `/usr/sbin/asterisk -rx "$asterisk_cmd" 2>\&1 `;
	return @ans;
}
sub RemoteAsterisk(){
	local($host_id,$url_path) = @_;
	local($browser,$response,$output);
	local($url);
	$url_path 	= (substr($url_path,0,1) ne "/") ? "/$url_path" : $url_path;
	#
	# ==========================================================================
	# host_id hardcoded for now
	# ==========================================================================
	# we need this id in a servers table. Each server has name, user/password,
	# ip, proto, tipo, etc etc ....
	$url 		= "http://$hardcoded_call_server_ip:171$url_path";
	# ==========================================================================
	#
	$browser	= null;
	$response	= null;
	$browser 	= LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 5);
	$response	= $browser->get($url);
	if ($response->is_success) {
		$output	= $response->content;
	} else {
		$output = "HTTP_ERROR_" . substr($response->status_line,0,3);
	}
	return($output);
}
sub RemoteAsterisk_AsArray(){
	local($host_id,$url_path) = @_;
	local($browser,$response,@output);
	local($url,$buf);
	$url_path 	= (substr($url_path,0,1) ne "/") ? "/$url_path" : $url_path;
	#
	# ==========================================================================
	# host_id hardcoded for now
	# ==========================================================================
	# we need this id in a servers table. Each server has name, user/password,
	# ip, proto, tipo, etc etc ....
	$url 		= "http://$hardcoded_call_server_ip:171$url_path";
	# ==========================================================================
	#
	$browser	= null;
	$response	= null;
	$browser 	= LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 }, timeout => 5);
	@output		= ();
	$response	= $browser->get($url);
	if ($response->is_success) {
		@output = split(/\n/,$response->content);
	}
	return(@output);
}
#------------------------
#
#------------------------
# asterisk manager libs
#------------------------
sub asterisk_manager_connect() {
	if ($asterisk_manager_is_connected eq 1) {return 1}
	$asterisk_manager_connection = Asterisk::AMI->new(	PeerAddr => $asterisk_manager_ip,
														OriginateHack => 1, 
                                						PeerPort => $asterisk_manager_port,
                                						Username => $asterisk_manager_user,
                                						Secret   => $asterisk_manager_secret
                         							);
	$asterisk_manager_is_connected = 1;
	return 1;
}
sub asterisk_manager_check_connection() {
	if ($asterisk_manager_is_connected eq 1) {return 1}
	return &asterisk_manager_connect();
}
sub asterisk_manager_command() {
        local(%my_action) = @_;
        asterisk_manager_check_connection();
#warning("== asterisk_manager_command START ==");
#warning(Dumper(%my_action));
        $asterisk_manager_response = $asterisk_manager_connection->action(\%my_action);
#warning(Dumper($asterisk_manager_response));
#warning("== asterisk_manager_command STOP ==");

}
sub asterisk_manager_command_simple() {
        local($cmd) =@_;
        local($tmp,$tmp1,$tmp2,$answer,%answer,%hash);
        %hash = ( Action => 'Command', Command => $cmd);
        $asterisk_manager_response = &asterisk_manager_command(%hash);
        %hash = %{$asterisk_manager_response};
        $tmp = join("\n",@{$hash{CMD}});
        return $tmp;
}
sub asterisk_manager_command_simple_as_array() {
        local($cmd) =@_;
        local($tmp,$tmp1,$tmp2,$answer,%answer,%hash,@out);
        %hash = ( Action => 'Command', Command => $cmd);
        $asterisk_manager_response = &asterisk_manager_command(%hash);
        %hash = %{$asterisk_manager_response};
        return @{$hash{CMD}};
}
#------------------------
#
#
#------------------------
# some lost things 
#------------------------
sub sql_to_hash_by_page(){
	#
	# basic, query sql database by page and put in hash
	# $data{DATA} is the same format as template loops. just drop DATA in the loop you want
	# remeber you NEED add " LIMIT #LIMIT1 , #LIMIT2" in your DATA query in order to limit page itens. 
	# 
	# her is a example how to query and add on template hash.
	# 
	#	==== CGI START ====
	#   %template_data = ();
	#	%users_list = &sql_to_hash_by_page((
	#		'sql_total'=>"SELECT count(*) FROM users ", 
	#		'sql_data'=>"SELECT id,name,phone FROM users ORDER BY date desc LIMIT #LIMIT1 , #LIMIT2 ",
	#		'sql_data_names'=>"user_id,user_name,user_phone",
	#		'page_now'=>$form{page_number},
	#		'page_size'=>5
	#	));
	#	if ($users_list{OK} eq 1){
	#		#
	#		# put DATA into users_list loop
	#	    $template_data{users_list_found}= 1;
	#		%{$template_data{users_list}}	= %{$users_list{DATA}};
	#		#
	#		# create loop with page info
	#		$template_data{users_list_page_min} = $users_list{page_min};
	#		$template_data{users_list_page_max} = $users_list{page_max};
	#		$template_data{users_list_page_now} = $users_list{page_now};
	#		$template_data{users_list_page_previous} = ($template_data{page_now} > $template_data{page_min}) ? $template_data{page_now}-1 : "";
	#		$template_data{users_list_page_next} = ($template_data{page_now} < $template_data{page_max}) ? $template_data{page_now}+1 : "";
	#		foreach $p ($users_list{page_min}..$users_list{page_max}) {
	#			$template_data{users_list_pages}{$p}{page} = $p;
	#			$template_data{users_list_pages}{$p}{selected} = ($p eq $t{thread_page}) ? 1 : 0;
	#		}
	#	}
	#    &template_print("template.html",%template_data);
	#	==== CGI STOP ====
	#
	#	==== TEMPLATE.HTML START ====
	#	<table>
	#	<TMPL_LOOP NAME="users_list">
	#		<tr>
	#		<td>%user_id%</td>
	#		<td>%user_name%</td>
	#		<td>%user_phone%</td>
	#		</tr>
	#	</TMPL_LOOP>
	#	</table>
	#	<br>
	#	Page %users_list_page_now% of %users_list_page_max%<br>
	#	Select page: 
	#	<TMPL_LOOP NAME="users_list_pages"><a href=?page_number=%page%>%page%</a>,</TMPL_LOOP>
	#	==== TEMPLATE.HTML STOP ====
	#
	local(%data) = @_;
	local(%hash,%hash1,$hash2,$tmp,$tmp1,$tmp2,@array,@array1,@array2);
	#
	# pega page limits
	%hash = &database_select($data{sql_total});
	$data{count} 		= ($hash{OK} eq 1) ? &clean_int($hash{DATA}{0}{0}) : 0;
	$data{count}		= ($data{count} eq "") ? 0 : $data{count};
	$data{page_size}	= &clean_int($data{page_size});
	$data{page_size}	= ($data{page_size} eq "") ? $workgroup_config{page_size} : $data{page_size};
	$data{page_size}	= ($data{page_size} > 1024) ? 1024 : $data{page_size};
	$data{page_size}	= ($data{page_size} < 1 ) ? 1 : $data{page_size};
	$data{page_min}		= 1;
	$data{page_max}		= int(($data{count}-1)/$data{page_size})+1;
	$data{page_max}		= ($data{page_max}<$data{page_min}) ? $data{page_min} : $data{page_max};
	$data{page_now} 	= &clean_int($data{page_now});
	$data{page_now} 	= ($data{page_now}<$data{page_min}) ? $data{page_min} : $data{page_now};
	$data{page_now} 	= ($data{page_now}>$data{page_max}) ? $data{page_max} : $data{page_now};
	$data{sql_limit_1}	= ($data{page_now}-1)*$data{page_size};
	$data{sql_limit_2}	= $data{page_size};
	#
	# pega ids
	if ($data{count} > 0){
		$data{sql_data_run} = $data{sql_data};
		$tmp2=$data{sql_limit_1}; $tmp1="#LIMIT1"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		$tmp2=$data{sql_limit_2}; $tmp1="#LIMIT2"; $data{sql_data_run} =~ s/$tmp1/$tmp2/eg;
		%hash = &database_select($data{sql_data_run},$data{sql_data_names});
		if ($hash{OK} eq 1) {
			%{$data{DATA}} = %{$hash{DATA}};
			$data{ROWS}	= $hash{ROWS};
			$data{COLS}	= $hash{COLS};
			$data{OK}	= 1;
		}
	}
	#
	# return
	return %data;
}
sub send_email(){
	local ($from,$to,$subject,$message,$has_head) = @_;
	local ($email_raw);
	$email_raw = "";
	$email_raw .= "from:$from\n";
	##$email_raw .= "To: $to\n";
	if (index("\U$message","SUBJECT:") eq -1) {$email_raw .= "Subject: $subject\n";}
	$email_raw .= "MIME-Version: 1.0\n";
	##$email_raw .= "Delivered-To: $to\n";
	if ($has_head ne 1) {$email_raw .= "\n";}
	$email_raw .= "$message\n";
	open(SENDMAIL,">>$app_root/website/log/send_email.log");
	print SENDMAIL  "\n";
	print SENDMAIL  "\n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "## NEW EMAIL TIME=(".time.") to=($to)\n";
	print SENDMAIL  "## \n";
	print SENDMAIL  "#########################################################\n";
	print SENDMAIL $email_raw;
	close(SENDMAIL);
	open(SENDMAIL, "|/usr/sbin/sendmail.postfix $to");
	print SENDMAIL $email_raw;
	close(SENDMAIL);
}
#------------------------
#
#------------------------

#------------------------
# clickchain (protect from url forge)

# CSV tools
#------------------------
sub csvtools_line_split_values(){
	local($line_raw) = @_; 
	local(@array,%hash,$tmp,,$tmp1,$tmp2,@1,@a2);
	local(@values);
    chomp($line_raw);
    chomp($line_raw);
    if (index($line_raw,",") eq -1) {$tmp1 = "\t"; $tmp2=","; $line_raw =~ s/$tmp1/$tmp2/eg;}
	@data = ();
	foreach $tmp (split(/\,/,$line_raw)) {
		$tmp1="\""; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp1="\'"; $tmp2=" "; $tmp =~ s/$tmp1/$tmp2/eg; 
		$tmp = trim($tmp);
		@data = (@data,$tmp);
	}
	return (@data);
}
sub csvtools_line_join_values(){
	local(@d) = @_;
	return join(",",@d);
}
#

# i just prototype this things..
# not working as the way i want
# later need comeback and fix the magic
#------------------------
sub form_check_float(){
	my ($v,$f) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	$v++;
	$v--;
	if ($v eq "0") {return 1}
	if ($v>0) {return 1}
	if ($v<0) {return 1}
	return 0;
}
sub form_check_integer(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_number(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_int($v)) {return 0}
	return 1;
}
sub form_check_string(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_url(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," /&?-_–(\@)-,=+;.<>[]:?<>","MINIMAL")) {return 0}
	return 1;
}
sub form_check_textarea(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," -_–(\@)-,=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_sql(){
	my ($v,$f) = @_;
	$v=trim($v);
	if (index("\L$f","allow_blank") eq -1){
		if ($v eq "") {return 0}
	}
	if ($v ne &clean_str($v," *-_–(\@)-,<>=+;.[]:?","MINIMAL")) {return 0}
	return 1;
}
sub form_check_email(){
	my ($v) = @_;
	$v=trim($v);
	if ($v eq "") {return 0}
	if ($v ne &clean_str($v,"–()_-=+;.?<>@","MINIMAL")) {return 0}
	if (index($v,"@") eq -1) {return 0}
	return 1;
}
#------------------------
#
#------------------------


#------------------------
# database abstraction
#------------------------
sub database_connect(){
	if ($database_connected eq 0) {
		$database = DBI->connect($database_dsn, $database_user, $database_password);
		$database->{mysql_auto_reconnect} = 1;
		$database_connected = 1;
	}
}
sub database_select(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$cols_string)=@_;
	local (@rows,@cols_name,$connection,%output,$row,$col,$col_name);
	@cols_name = split(/\,/,$cols_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$row=0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$col=0;
			foreach (@rows){
				$col_name =  ((@cols_name)[$col] eq "")  ? $col : (@cols_name)[$col] ; 
				$output{DATA}{$row}{$col_name}= $_;
				#$output{DATA}{$row}{$col}= &database_scientific_to_decimal($_);
				$col++;
			}
			$row++;
		}
		$output{ROWS}=$row;
		$output{COLS}=$col;
		$output{OK}=1;
	} else {
		$output{ROWS}=0;
		$output{COLS}=0;
		$output{OK}=0;
	}
	return %output;
}
sub database_select_as_hash(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			if ($rows_string eq "") {
				$output{(@rows)[0]}=(@rows)[1];
			} else {
				$i=0;
				foreach (@rows_name) {
					##$output{(@rows)[0]}{$_} = &database_scientific_to_decimal((@rows)[$i+1]);
					$output{(@rows)[0]}{$_} = (@rows)[$i+1];
					$i++;
				}
			}
		}
	}
	return %output;
}
sub database_select_as_hash_with_auto_key(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,%output,$line_id);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		$line_id = 0;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			$i=0;
			foreach (@rows_name) {
				$output{$line_id}{$_} = &database_scientific_to_decimal((@rows)[$i]);
				$i++;
			}
			$line_id++;
		}
	}
	return %output;
}
sub database_select_as_array(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql,$rows_string)=@_;
	local (@rows,@rows_name,$i,@output);
	@rows_name = split(/\,/,$rows_string);
	if ($database_connected eq 1) {
		$connection = $database->prepare($sql);
		$connection->execute;
		while ( @rows = $connection->fetchrow_array(  ) ) {
			@output = ( @output , &database_scientific_to_decimal((@rows)[0]) );
		}
	}
	return @output;
}
sub database_do(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output);
	$output = "";
	if ($database_connected eq 1) {	$output = $database->do($sql) }
	if ($output eq "") {$output =-1;}
	return $output;
}
sub database_scientific_to_decimal(){
	local($out)=@_;
	local($tmp1,$tmp2);
	if ( index("\U$out","E-") ne -1) {
		($tmp1,$tmp2) = split("E-","\U$out");
 		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=sprintf("%f",$out);
		}
	}
	if ( index("\U$out","E+") ne -1) {
		($tmp1,$tmp2) = split("E","\U$out");
		$tmp2 = substr($tmp2,1,10);
		$tmp1++;
		$tmp2++;
		$tmp1--;
		$tmp2--;
		if (  (&is_numeric($tmp1) eq 1) && (&is_numeric($tmp2) eq 1)  )  {
			$out=int(sprintf("%f",$out));
		}
	}
	return $out;
}
sub database_clean_string(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_clean_number(){
	my $string = @_[0];
	return &database_escape($string);
}
sub database_escape {
	my $string = @_[0];
	$string =~ s/\\/\\\\/g ; # first escape all backslashes or they disappear
	$string =~ s/\n/\\n/g ; # escape new line chars
	$string =~ s/\r//g ; # escape carriage returns
	$string =~ s/\'/\\\'/g; # escape single quotes
	$string =~ s/\"/\\\"/g; # escape double quotes
	return $string ;
}
sub database_do_insert(){
	if ($database_connected ne 1) {database_connect()}
	local ($sql)=@_;
	local ($output,%hash,$tmp);
	$output = "";
	#
	# new code (return last insert_id)
	if ($database_connected eq 1) {
		if ($database->do($sql)) {
			%hash = &database_select_as_hash("SELECT 1,LAST_INSERT_ID();");
			return $hash{1};
		} else {
			return "";
		}
	} else {
		return "";
	}
}
sub database_escape_sql(){
	local($sql,@values) = @_;
	retutn &database_scape_sql($sql,@values);
}
sub database_scape_sql(){
	local($sql,@values) = @_;
	local($tmp,$tmp1,$tmp2);
	$tmp1="\t"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\n"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp1="\r"; $tmp2=" "; $sql =~ s/$tmp1/$tmp2/eg;
	$tmp = @values;
	$tmp--;
	if ($tmp>0) {
		foreach (0..$tmp) {
			$values[$_] = &database_escape($values[$_]);
		}
	}
	return  sprintf($sql,@values);
}
#------------------------
#
#------------------------

# generic perl library
#------------------------
sub get_today(){
	local($my_time)=@_;
	local (%out,@mes_extenso,$sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	if ($my_time eq "") {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime(time);
	} else {
		($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =	localtime($my_time);
	}
	if ($year < 1000) {$year+=1900}
	$mon++;
	$out{DAY}		= $mday;
	$out{MONTH}		= $mon;
	$out{YEAR}		= $year;
	$out{HOUR}		= $hour;
	$out{MINUTE}	= $min;
	$out{SECOND}	= $sec;
	$out{DATE_ID}	= substr("0000".$year,-4,4) . substr("00".$mon,-2,2) . substr("00".$mday,-2,2);
	$out{TIME_ID}	= substr("00".$hour,-2,2) . substr("00".$min,-2,2) . substr("00".$sec,-2,2);
	$out{DATE_TO_PRINT} = &format_date($out{DATE_ID});
	$out{TIME_TO_PRINT} = substr("00".$hour,-2,2) . ":" . substr("00".$min,-2,2);
	return %out;
}
sub format_date(){
	local($in)=@_;
	local($out,$tmp1,$tmp2,@mes_extenso);
	@mes_extenso = qw (ERROR Janeiro Fevereiro Março Abril Maio Junho Julho Agosto Setembro Outubro Novembro Dezembro);
	@mes_extenso = qw (ERROR Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	if (length($in) eq 8) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4);
	} elsif (length($in) eq 14) {
		$tmp1=substr($in,4,2);
		$tmp2=substr($in,6,2);
		$tmp1++;$tmp1--;
		$tmp2++;$tmp2--;
		$out = (@mes_extenso)[$tmp1] . " $tmp2, " . substr($in,0,4)  ." at ".substr($in,8,2).":".substr($in,10,2) ;
	} else {
		$tmp1=substr($in,4,2);
		$tmp1++;$tmp1--;
		$out = (@mes_extenso)[$tmp1] . ", " .substr($in,0,4);
	}
	return $out;
}
sub clean_str() {
  #limpa tudo que nao for letras e numeros
  local ($old,$extra1,$extra2)=@_;
  local ($new,$extra,$i);
  $old=$old."";
  $new="";
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_.".$extra1; 		# new default
  $caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_. @".$extra1; 	# using old default to be compatible with old cgi
  if ($extra1 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra2;}
  if ($extra2 eq "MINIMAL") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890".$extra1;}
  if ($extra1 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra2;}
  if ($extra2 eq "URL") 	{$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\%".$extra1;}
  if ($extra1 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra2;}
  if ($extra2 eq "SQLSAFE") {$caracterok="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890/\&\$\@#?!=:;-_+.(),'{}^~[]<>\% ".$extra1;}
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $new;
}
sub clean_int() {
  #limpa tudo que nao for letras e numeros
  local ($old)=@_;
  local ($new,$pre,$i);
  $pre="";
  $old=$old."";
  if (substr($old,0,1) eq "+") {$pre="+";$old=substr($old,1,1000);}
  if (substr($old,0,1) eq "-") {$pre="-";$old=substr($old,1,1000);}
  $new="";
  $caracterok="1234567890";
  for ($i=0;$i<length($old);$i++) {if (index($caracterok,substr($old,$i,1))>-1) {$new=$new.substr($old,$i,1);} }
  return $pre.$new;
}
sub clean_float() {
	local ($old)=@_;
	local ($new,$n1,$n2);
	if (index($old,".") ne -1) {
		($n1,$n2) = split(/\./,$old);
		$new = &clean_int($n1).".".&clean_int($n2);
	} else {
		$new = &clean_int($old);
	}
	return $new;
}
sub clean_html {
  local($trab)=@_;
  local($id,@okeys);
  @okeys=qw(b i h1 h2 h3 h4 h5 ol ul li br p B I H1 H2 H3 H4 H5 OL UL LI BR P);
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/<$id>/[$id]/g;
    $trab=~ s/<\/$id>/[\/$id]/g;
  }
  $trab=~ s/</ /g;
  $trab=~ s/>/ /g;
  foreach(@okeys) {
    $id=$_;
    $trab=~ s/\[$id\]/<$id>/g;
    $trab=~ s/\[\/$id\]/<\/$id>/g;
  }
  return $trab;
}
sub is_numeric() {
	local($num) = @_;
	$num = trim($num);
	$p1 = "";
	$p1 = (substr($num,0,1) eq "-") ? "-" : $p1;
	$p1 = (substr($num,0,1) eq "+") ? "+" : $p1;
	$p0 = ($p1 eq "") ? $num : substr($num,1,1000);
	$p5="";
	if (index($p0,".")>-1) {
		($p2,$p3,$p4) = split(/\./,$p0);
		$p2 =~ s/[^0-9]/$p5/eg;
		$p3 =~ s/[^0-9]/$p5/eg;
		if ( ("$p1$p2.$p3" eq $num) && ($p4 eq "") ){return 1} else {return 0}
	} else {
		$p0 =~ s/[^0-9]/$p5/eg;
		if ("$p1$p0" eq $num) {return 1} else {return 0}
	}
}
sub trim {
     my @out = @_;
     for (@out) {
         s/^\s+//;
         s/\s+$//;
     }
     return wantarray ? @out : $out[0];
}
sub format_number {
	local $_  = shift;
	local $dec = shift;
	#
	# decimal 2 its a magic number.. 2 decimals but more decimals for small numbers
	if (!$dec) {
		$dec="%.0f";
	} elsif ($dec eq 2) {
		$dec="%.2f";
		if($_<0.05) 		{$dec="%.3f"}
		if($_<0.005) 		{$dec="%.4f"}
		if($_<0.0005) 		{$dec="%.5f"}
		if($_<0.00005) 		{$dec="%.7f"}
		if($_<0.000005) 	{$dec="%.8f"}
		if($_<0.0000005) 	{$dec="%.9f"}
		if($_<0.00000005) 	{$dec="%g"}
	} else {
		$dec="%.".$dec."f";
	}
	$_=sprintf($dec,$_);
	1 while s/^(-?\d+)(\d{3})/$1,$2/;
	return $_;
}
sub format_time {
        local ($sec) = @_;
        local ($out,$min,$hour,$tmp);
        $sec = int($sec);
        if ($sec < 60) {
                $out = substr("00$sec",-2,2)."s";
                $out = $sec."s";
        } elsif ($sec < (60*60) ) {
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $min."m ".$sec."s";
        } else {
                $hour = int($sec/(60*60));
                $sec = $sec - ($hour*(60*60));
                $min = int($sec/60);
                $sec = $sec - ($min*60);
                $out = $hour."h ".substr("00$min",-2,2)."m ".substr("00$sec",-2,2)."s";
                $out = $hour."h ".$min."m ".$sec."s";
        }
        return $out;
}
sub format_time_gap {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days,%tmpd);
        %d = &get_today($time);
        $sec = int(time-$time);
        if ($sec < 60) {
            $out = "$sec seconds ago";
        } elsif ($sec < (60*60) ) {
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$min minutes ago";
        } elsif ($sec < (60*60*6))  {
            $hour = int($sec/(60*60));
            $sec = $sec - ($hour*(60*60));
            $min = int($sec/60);
            $sec = $sec - ($min*60);
            $out = "$hour hours ago";
        } elsif ($sec < (60*60*24*60))  {
	    %tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY} $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        } else {
	    %tmpd = &get_today($time);
            $out = "$tmpd{MONTH}/$tmpd{DAY}/".substr($tmpd{YEAR},-2,2)." $tmpd{HOUR}:".substr("00".$tmpd{MINUTE},-2,2);
        }
        return $out ;
}
sub format_time_time {
        local ($time) = @_;
        local ($out,$gap,%d,$min,$hour,$days);
        %d = &get_today($time);
        return "$d{DATE_TO_PRINT} $d{TIME_TO_PRINT}" ;
}
sub check_email() {
  local ($old_email)=@_;
  local ($tmp1,$tmp2,$tmp2,$email,$ok);
  ($tmp1,$tmp2,$tmp3)=split(/\@/,$old_email);
  $tmp1 = &clean_str($tmp1,"._-","MINIMAL");
  $tmp2 = &clean_str($tmp2,"._-","MINIMAL");
  $email = "$tmp1\@$tmp2";
  $ok = 1;
  if (index($email,"@") eq -1) 	{$ok=0;}
  if (index($email,".") eq -1) 	{$ok=0;}
  if ($tmp3 ne "") 				{$ok=0;}
  if ($email ne $old_email) 	{$ok=0;}
  return $ok
}
sub format_dial_number() {
	my($in) = @_;
	my($out,$length);
	$in=&clean_int(substr($in,0,100));
	$out=$in;
	$length=length($in);
	if ($length eq 5) {
		$out = substr($in,0,2)."-".substr($in,2,3);
	} elsif ($length eq 6) {
		$out = substr($in,0,3)."-".substr($in,3,3);
	} elsif ($length eq 7) {
		$out = substr($in,0,3)."-".substr($in,3,4);
	} elsif ($length eq 8) {
		$out = substr($in,0,4)."-".substr($in,4,4);
	} elsif ($length eq 9) {
		$out = "(".substr($in,0,2).") ".substr($in,2,3)."-".substr($in,5,3);
	} elsif ($length eq 10) {
		$out = "(".substr($in,0,3).") ".substr($in,3,3)."-".substr($in,6,4);
	} elsif ($length eq 11) {
		$out = substr($in,0,1)." (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
	} elsif ($length eq 12) {
		$out = substr($in,0,2)." (".substr($in,2,3).") ".substr($in,5,3)."-".substr($in,8,4);
	}
	return($out)
}
sub multiformat_phone_number_check_user_input(){
	my($in) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	my($flag,$number_e164,$country);
	if (trim($in) eq "") {return ("EMPTY","UNKNOWN",$in);}

	$tmp = "\U$in";
	unless($tmp =~ m/[A-Z]/) {

		#
		# numeric.. lets check e164
		($flag,$number_e164,$country) = &multilevel_check_E164_number(&clean_int($in));
		if ($flag eq "USANOAREACODE") {
			return ("OK","E164","1$number_e164");
		} elsif ($flag eq "UNKNOWNCOUNTRY") {
			return ("UNKNOWNCOUNTRY","E164",$in);
		} elsif ($flag eq "OK") {
			return ("OK","E164",$number_e164);
		} else {
			return ("ERROR","E164",$in);
		}
	} else {
		# 
		# alpha, lets clean skype
		if (index($in,":") ne -1){	
			($tmp1,$tmp2) = split(/\:/,$in);$in = $tmp2; 
		}
		$tmp = &trim($in);
		$tmp1 = &clean_str($tmp,"-_.","MINIMAL");
		if ( ($tmp1 eq $tmp) && (length($tmp1)>=6) && (length($tmp1)<=32) ) {
			return ("OK","SKYPE",$tmp);
		} else {
			return ("ERROR ($in) ($tmp) ($tmp1) (".length($tmp1).") ","SKYPE",$in);
		}
	}
}
sub multiformat_phone_number_format_for_user(){
	my($in,$format_type) = @_;
	my($out,%hash,$tmp1,$tmp2,$contry,$tmp);
	if ($in eq "") {return "";}
	if (&clean_int($in) eq $in){
		return &format_E164_number($in,$format_type);
	} else {
		return "Skype: $in";
	}
}
sub format_E164_number() {
	my($in,$format_type) = @_;
	my($out,%hash,$contry,$tmp);
	#
	#
	if ($in eq "") {return ""}
	#
	# get country list
	if ($app{country_buffer} eq "") {
	    %hash = &database_select_as_hash("select code,name from country ");
	    $app{country_buffer} = "|";
		$app{country_max_length} = 0;
	    foreach (keys %hash) {
			$app{country_buffer} .= "$_|";
			$app{country_max_length} = (length($_)>$app{country_max_length}) ? length($_) : $app{country_max_length};
		}
	}
	$country = "";
	foreach $tmp (1..$app{country_max_length}) {
		$tmp1 = substr($in,0,$tmp);
		if (index($app{country_buffer},"|$tmp1|") ne -1) {$country = $tmp1;}
	}
	$out = $in;
	if ($format_type eq "E164") {
		if ($country eq "") {
			$out = "+$in";
		} elsif ($country eq "1") {
			$out = "+1 (".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "+55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "+$country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} elsif ($format_type eq "USA") {
		if ($country eq "") {
			$out = "+$in";
		} elsif  ( ($country eq "1") && (length($in) eq 11)) {
			$out = "(".substr($in,1,3).") ".substr($in,4,3)."-".substr($in,7,4);
		} elsif ($country eq "55") {
			$out = "011 55 (".substr($in,2,2).") ".substr($in,4,4)."-".substr($in,8,4);
		} else {
			$tmp = length($country);
			$out = "011 $country (".substr($in,$tmp,3).") ".substr($in,$tmp+3,3)."-".substr($in,$tmp+6,1000);
		}
	} else {
	}
	return $out;
}
sub format_key_code(){
	local($in)=@_;
	local($t,$t1,$t2,$o,$c,$l,@a);
	$c = 0;
	$l = 1;
	$o = "";
	@a = ();
	while($l eq 1) {
		$t1 = trim(substr($in,-3,3));
		$t2 = trim(substr($in,0,-3));
		@a = (substr("0000$t1",-3,3),@a);
		if ($t2 eq "") {$l=0}
		$c++; if ($c>20){last}
		$in = $t2;
	}
	$o = join("-",@a);
	return $o;
}
sub format_pin(){
	local($in)=@_;
	local($t,$t1,$t2,$out,$c,$l,@a);
	$out=$in;
	if (length($in) eq 8){
		#$out = substr($in,0,3)."-".substr($in,3,2)."-".substr($in,5,3);
		$out = substr($in,0,2)."-".substr($in,2,2)."-".substr($in,4,4);
	}
	return $out;
}
sub format_trim_name(){
	local($in,$flag) = @_;
	local($out,$w);
	$out=$in;
	#
	# hack: show all names with no obfuscate
	$flag = 0;
	#
	if ($flag eq 1) {
	    $out = "";
	    foreach $w (split (/ +/,$in)){
		if ($w eq "") {next}
		$out .= (length($w)>2) ? substr("\U$w",0,1)."**** " : "$w ";
	    }
	}
	return $out;
}
#------------------------

sub genuuid () {
  @char = (0..9,'a'..'f');
  $size = int @char;
  local $uuid = '';
  for (1..8) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-';
  for (1..4) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-4';

  for (1..3) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-8';
  for (1..3) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }
  $uuid .= '-';

  for (1..12) {
      $s = int rand $size;
      $uuid .= $char[$s];
  }

  return $uuid;
}

sub Json2Hash(){
	local($json_plain) = @_;
	local(%json_data);
	my %json_data = ();
	if ($json_plain ne "") {
		my $json_data_reference	= $json_engine->decode($json_plain);
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