#!/usr/bin/perl
#======================================================
# load head
#======================================================
use IO::Socket;
use Data::Dumper;
use DBI;
use Time::Local;

require "/salzh/codes/lib/default.include.pl";
#======================================================


#======================================================
# config
#======================================================
$conference_host 	= $host_name;
$version 			= "1.0.2";
$debug 				= 0;
$fork 				= 0;
$file_pid 			= "/var/run/app_konference.pid";

$host 				= "127.0.0.1";
$port 				= 5038;
$user 				= "admin";
$secret 			= "RXIagnjrl9mq"; 
$EOL 				= "\015\012";
$BLANK 				= $EOL x 2;
%dtmf_buffer 		= ();
%automute_buffer	= ();
%poll_buffer		= ();
%buffer 			= ();
#======================================================



#======================================================
# arguments
#======================================================
$arguments = join(" ",@ARGV);
$arguments = " \L$arguments ";
if (index($arguments," version ") ne -1) {
	print $version . "\n";
	exit;
}
if (index($arguments," log ") ne -1) {
	$debug = 1;
}
if (index($arguments," logverbose ") ne -1) {
	$debug = 1;
	$|=1;
}
if (index($arguments," daemon ") ne -1) {
	$fork = 1;
	$|=1;
}
if (index($arguments," restart ") ne -1) {
	open FILE, "$file_pid " or die $!;
	my @lines = <FILE>;
	foreach(@lines) {
		`kill -9 $_` 
	}
	close(FILE);
	unlink("$file_pid");
}
#======================================================




#======================================================
# fork
#======================================================
if ($fork == 1) {
	chdir '/'                 or die "Can't chdir to /: $!";
	#umask 0;
	open STDIN, '/dev/null'   or die "Can't read /dev/null: $!";
	open STDOUT, ">> $file_log" or die "Can't write to $file_log: $!";
	open STDERR, ">> $file_log" or die "Can't write to $file_log: $!";
	defined(my $pid = fork)   or die "Can't fork: $!";
	exit if $pid;
	setsid                    or die "Can't start a new session: $!";
	$pid = $$;
	open FILE, ">", "$file_pid";
	print FILE $pid;
	close(FILE);
}
$t = getTime();
if (index($arguments," restart ") ne -1) {
	print STDERR "$t STATUS: Listener restarted\n";
}
#======================================================


=pod
Event: Bridge
Privilege: call,all
Bridgestate: Link
Bridgetype: core
Channel1: SIP/velantro245-new-00007795
Channel2: SIP/67.231.3.4-00007796
Uniqueid1: 1596768596.30613
Uniqueid2: 1596768597.30614
CallerID1: 8186415522
CallerID2: 14805473667
=cut


#======================================================
# main loop
#======================================================
my @commands;
reconnect:
$remote = IO::Socket::INET->new(
    Proto => 'tcp',
    PeerAddr=> $host,
    PeerPort=> $port,
    Reuse   => 1
) or die goto reconnect;
$t = getTime();
print STDERR "$t STATUS: Connected\n";
$remote->autoflush(1);
$logres = login_cmd("Action: Login${EOL}Username: $user${EOL}Secret: $secret${BLANK}");
$eventcount = 0;
while (<$remote>) {
	$_ =~ s/\r\n//g;
	$_ = trim($_);
	if ($_ eq "") {
		if ($finalline =~ /Event/) {
			# get regular event data
			$finalline = ltrim($finalline);
			@raw_data = split(/\;/, $finalline);			
			%event = ();
			$t = getTime();
			foreach(@raw_data) {
				@l = split(/\: /,$_);
				$event{$l[0]} = $l[1];
			}
			# expand zenofon extra data at "type" field
			($tmp1,$tmp2,$tmp3,$tmp4) = split(/\|/,$event{Type});
			$event{ZenofonBillingID} = &clean_int($tmp1);
			# call action
			if ($event{Event} =~ /^Bridge/) {
				
			}
			
			if ($event{Event} eq 'BridgeEnter') {
				print Data::Dumper::Dumper(\%event);
				&bridge(%event);
			}
			$eventcount++;
		} 
		$finalline="";
	}
	if ($_ ne "") {
		$line = $_;
		if ($finalline eq "") {
			$finalline = $line;
		} else {
			$finalline .= ";" . $line;
		}
	}
}
$t = getTime();
print STDERR "$t STATUS: Connection Died\n";
goto reconnect;
#======================================================


#======================================================
# poll actions
#======================================================

sub bridge() {
	local(%event) = @_;
	local $response = &asterisk_manager_command('Action' => 'Getvar', 'Channel' => $event{Channel}, 'Variable' => 'ticketid');
	#print Data::Dumper::Dump($response);
	local $ticketid = $response->{PARSED}{Value};
	($extension) = $event{Channel} =~ m{SIP/(.+)\-(\w+)$};
}

sub command {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
       return $buf; 
}
sub getTime {
	@months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
	@weekDays = qw(Sun Mon Tue Wed Thu Fri Sat Sun);
	($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
	$year = 1900 + $yearOffset;
	if ($hour < 10) {
		$hour = "0$hour";
	}
	if ($minute < 10) {
		$minute = "0$minute";
	}
	if ($second < 10) {
		$second = "0$second";
	}
	$theTime = "[$months[$month] $dayOfMonth $hour:$minute:$second]";
	return $theTime; 
}
sub login_cmd {
        my $cmd = @_[0];
        my $buf="";
        print $remote $cmd;
        return $buf;
}
sub DELETE_trim($) {                                   
        my $string = shift;                     
        $string =~ s/^\s+//;                    
        $string =~ s/\s+$//;            
        return $string;                         
}                                               
sub ltrim($)                             
{                                
        my $string = shift;
        $string =~ s/^\s+//;
        return $string;
}       
sub rtrim($)
{               
        my $string = shift;
        $string =~ s/\s+$//;
        return $string;
}
sub asterisk_debug_print(){
	local($msg) = @_;
	print STDERR "$msg \n";
	
}
#======================================================
 