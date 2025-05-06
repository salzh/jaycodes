#!/usr/bin/perl
use CGI::Simple;
$CGI::Simple::DISABLE_UPLOADS = 0;
$CGI::Simple::POST_MAX = 1_000_000_000;
use URI::Escape;
#use utf8;
my $cgi   = CGI::Simple->new();

=pod
$infile  = shift || die "no inputfile";
$outfile = shift;

if (!-e $infile) {
    die "$infile not found!"
}

$text = `cat $infile`;
=cut
$text = $cgi->param('q');

$text =~ s/[\r\n]/,/g;
$default_tl   = 'zh';
$default_tl   = 'en' if $text =~ s/^EN//;
=pod
for (',',':','.',';','!','，','。','；','！','：') {
    print "$_: " . uri_escape($_), "\n";
}
=cut
=pod
,: %2C
:: %3A
.: .
;: %3B
!: %21
，: %EF%BC%8C
。: %E3%80%82
；: %EF%BC%9B
！: %EF%BC%81
：: %EF%BC%9A
=cut

#$text = uri_escape($text);
@tmpfiles = ();

$text = uri_escape $text;
#warn $text;

for $str (split /,|;|:|%2C|%3A|\.|%3B|%21|%EF%BC%8C|%E3%80%82|%EF%BC%9B|%EF%BC%81|%EF%BC%9A/, $text) {
    $str =uri_unescape $str;
    next if $str =~ /^\s*$/; 
    if ($str =~ /_E(.+?)_E/) {
        $str = $1;
        $tl  = 'en';
    } else {
        $tl  = $default_tl;
    }
    #warn $str;
    $tmp  = "/tmp/" . time . int(rand 9999);
    $url  = "http://translate.google.com/translate_tts?ie=UTF-8&tl=$tl&q=$str";
    warn $url . "\n";
    
    $res = `wget -q -U Mozilla -O $tmp.mp3 "$url"`;
    $res = `sox $tmp.mp3 -c1 -r 32000 "$tmp-8000.mp3"`;
    unlink "$tmp.mp3";
    push @tmpfiles, "$tmp-8000.mp3";
}

$mp3files = join " ", @tmpfiles;
$outfile  = '/tmp/' . time . '.wav';

$res = `sox $mp3files -c1 -r 8000 "$outfile"`;

unlink @tmpfiles;
if (! -e $outfile) {
    #die "$outfile not generated";
    print $cgi->header();
    print "fail to generate audio file";
    exit 0;
}


#print "$outfile ok!";
$len = -s $outfile;
print $cgi->header('-type' => 'audio/wav');
open FH, $outfile;

sysread FH, $buffer,$len;
close FH;

unlink $outfile;
print $buffer



