use strict;
use warnings;
use Test::More;
use Mojolicious::Plugin::Kong::SharedSecret;

my $plugin        = Mojolicious::Plugin::Kong::SharedSecret->new();
my $expected_conf = {
    kong_url      => 'http://foobar.org:8001',
    header_name   => 'Cool-Header-Bro',
    cache_seconds => 600
};

is_deeply(
    $plugin->_merge_default_conf(
        {   kong_url    => 'http://foobar.org:8001',
            header_name => 'Cool-Header-Bro'
        }
    ),
    $expected_conf,
    'Conf merged correctly'
);
done_testing();
