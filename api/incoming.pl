#!/usr/bin/perl

use CGI::Simple;
use JSON; # to install, # sudo cpan JSON
require "/usr/local/owsline/lib/default.include.pl";

my $json_engine;

unless ($json_engine) {$json_engine = JSON->new->allow_nonref;}

$cgi = CGI::Simple->new();
$action = $cgi->param('action');

if ($action eq 'getincomingevent') {
	print $cgi->header(-type  =>  'text/event-stream;charset=UTF-8', '-cache-control' => 'NO-CACHE', );
} else {
	print $cgi->header();
	
}

$ext = $cgi->param('ext');
if (!$ext) {
    print "ext is null";
    exit 0;
}

use Cache::Memcached;
	my $memcache = "";
    my $memcache = new Cache::Memcached {'servers' => ['127.0.0.1:11211'],};
	
if ($action eq 'getincomingevent') {
    &get_incoming_event($ext);
} elsif ($action eq 'openticket') {
    &open_ticket($ext);
}

sub open_ticket() {
    my $ext =  shift;
    my @channels = &asterisk_manager_command_simple_as_array("core show channels concise");;
    local $ticketid, $found_ext, $ext_channel, $peer_channel;
	local %channel_hash = ();
	for my $line (@channels) {
		my @f = split '!', $line;
		if ($f[0] =~ /SIP\/$ext\-/ ) { #presence_id && initial_ip_addr			
            if ($f[12]) {
				$found_ext   = 1;
				$ext_channel = $f[0];
            }
			
        }
		$channel_hash{$f[0]}= $f[12];

    }
    
	if ($found_ext) {
		$peer_channel = $channel_hash{$ext_channel};
		if ($peer_channel =~ /^Local/) {
			$peer_channel =~ s/;2/;1/;
			$peer_channel = $channel_hash{$peer_channel};
		}		
	}
	
	local %hash = &Json2Hash($memcache->get($peer_channel));
    $ticketid = $hash{ticketid};
	
	warn "$ticketid, $found_ext, $ext_channel, $peer_channel";
	
    if ($ticketid) {
        warn "found ticketid=$ticketid";
		print
"<script>
	window.location.href='http://member.cfbtel.com/admin/supporttickets.php?action=view&id=$ticketid';
</script>
";
    } else {
        print "not found ticketid for $ext, pls refresh ..."
    }
    
    exit 0;
      
}

=pod
[root@officepbx api]# asterisk -rx "core show channels concise"
SIP/106-00000177!macro-dial-one!s!44!Ring!Dial!SIP/105&SIP/99105,20,TtrI!106!!!3!7!(None)!1435996531.5869
SIP/105-00000178!from-internal!105!1!Ringing!AppDial!(Outgoing Line)!105!!!3!7!(None)!1435996531.5870
[root@officepbx api]# asterisk -rx "core show channels concise"
SIP/106-00000179!macro-dial-one!s!44!Up!Dial!SIP/105&SIP/99105,20,TtrI!106!!!3!9!SIP/105-0000017a!1435996552.5871
SIP/105-0000017a!from-internal!!1!Up!AppDial!(Outgoing Line)!105!!!3!9!SIP/106-00000179!1435996553.5872
=cut

sub get_incoming_event {
	my $ext = shift;
	my $domain  = $query{domain} || $HOSTNAME;
	$domain		= $cgi->server_name();
	
	$tid = _uuid();	$ext_tid = "$ext-$tid";

	
	$memcache->delete($ext_tid);

	my $starttime = time;
	local $| = 1;
CHECK:
	
	if (time - $starttime > 3600) {
		$memcache->delete($ext_tid);
		exit 0; #force max connection time to 1h
	}
	
	my $status = $memcache->get($ext_tid);
	my $current_state = '';
	
	my @channels = &asterisk_manager_command_simple_as_array("core show channels concise");;
	my $cnt      = 0;
	for my $line (@channels) {
		my @f = split '!', $line;
		#warn $line;
		if ($f[0] =~ /SIP\/$ext\-/ ) { #presence_id && initial_ip_addr
			
			$current_state = $f[4];
			if ($status ne $current_state) {
                if ($f[12]) {
                    local %hash = &Json2Hash($memcache->get($f[12]));
                    #$cid = $hash{callerid};
                } else {
                    #$cid = $f[7];
                }
                
				local @lines =  &asterisk_manager_command_simple_as_array("core show channel $f[0]");
                local ($cidname, $cidnumber);
				for (@lines) {
					if ($_ =~ /^Connected Line ID: (.*)$/) {
						$cidnumber = $1;
					} elsif ($_ =~ /^Connected Line ID Name: (.*)$/) {
						$cidname = $1;
					}
					
				}
                
				$state = $f[4];
				if ($state eq 'Ringing') {
					$state = 'RINGING';
				} elsif ($state eq 'Up') {
					$state = 'ACTIVE';
				}
				
				print "data:",&Hash2Json(error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => $f[0],
					 caller => "$cidname <$cidnumber>", start_time => time, current_state => $state), "\n\n";
				$memcache->set($ext_tid, $current_state);
			}
		}		
	}
	
	if (!$current_state) {
		if (!$status) {
			
			print "data:" , &Hash2Json(error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => '',
					 caller => "", start_time => '', current_state => 'nocall'), "\n\n";
			$memcache->set($ext_tid, 'nocall');
		} elsif ($status ne 'nocall') {
			print "data:", &Hash2Json(error => '0', 'message' => 'ok', 'actionid' => $query{actionid}, uuid => '',
					 caller => "", start_time => '', current_state => 'hangup'), "\n\n";
			$memcache->set($ext_tid, '');
		}
	}
	
	sleep 1;
	goto CHECK;
}

exit 0;


sub reply_error (){
	print build_reply({status => 0, message => shift});

	exit 0;
}

sub build_reply (){
	my $arg    = shift || {};
	my $hash   = {};
	
	$hash->{status} = $arg->{status} ||0;
	$hash->{message} = $arg->{message} || '';
	
	while (my ($k, $v) = each %$arg) {
		next if !$k || $k eq 'status' || $k eq 'message';
		$hash->{$k} = defined $v ? $v : '';
		#$retstr .= "<$k>" . (defined $v ? $v : '') . "</$k>";
	}

	#$retstr   .= "</response>";

	return $json_engine->encode($hash);
}

sub _uuid {
	my $str = `uuid`;
	$str =~ s/[\r\n]//g;
	
	return $str;
}