use Net::AMQP::RabbitMQ;
require "/salzh/code/ivr/lib/default.include.pl";

my $mq = Net::AMQP::RabbitMQ->new();
$mq->connect("localhost", { user => "guest", password => "guest" });
$mq->channel_open(1);
$mq->queue_declare(1, "incoming");
$mq->publish(1, "incoming", '{"ticketid":"20408","to":"101","domain_name":"jaypbx.cfbtel.com"}');
