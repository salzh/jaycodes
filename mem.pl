require "/usr/local/owsline/lib/default.include.pl";
use Cache::Memcached;

$channel = shift;
$ticketid = shift;


local %hash = (ticketid => $ticketid, callerid => 888888, 'starttime' => time);

my $memcache = "";
my $memcache = new Cache::Memcached {'servers' => ['127.0.0.1:11211']};
if ($ticketid) {
    $memcache->set($channel, &Hash2Json(%hash),600);
} else {


    $json = $memcache->get($channel);
    
    warn "$channel was set to $json";
}
               
               

	