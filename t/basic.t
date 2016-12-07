use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'Kong::SharedSecret';

get '/' => sub {
    my $c = shift;
    $c->render( text => 'Hello Mojo!' );
};

my $t = Test::Mojo->new;
$t->get_ok('/')->status_is(200)->content_is('Hello Mojo!');

isa_ok(
    app->kong_secret_cache(),
    'Cache::Memory::Simple',
    'cached object returns from kong_secret_cache helper'
);

done_testing();
