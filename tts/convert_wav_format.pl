@files = qw/10.wav  11.wav  12.wav  13.wav  2.wav  3.wav  4.wav  5.wav  6.wav  7.wav  8.wav  9.wav  ann.wav/;

for (@files) {
    system("sox /var/lib/asterisk/sounds/whmcs/$_ -c1 -r 8000 /var/lib/asterisk/sounds/whmcs1/$_");
}