use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use Test::MockModule;

plugin 'Kong::SharedSecret';

my $kong_secured_routes = app->kong_secured_routes();

$kong_secured_routes->get('/')->to(
    cb => sub {
        my $c = shift;
        $c->render( text => 'Hello Mojo!' );
    }
);

my $t = Test::Mojo->new;
subtest 'unauthorized when header not present' => sub {
    $t->get_ok('/')->status_is(403)->content_is('Unauthorized');
};

subtest 'unauthorized when secret does not match' => sub {
    my $mock_shared_secret = Test::MockModule->new('Kong::SharedSecret');
    $mock_shared_secret->mock(
        'fetch_shared_secret',
        sub {
            my ( undef, undef, $cb ) = @_;
            $cb->( 'Mock::SharedSecret', 'barfoo' );
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(403)
        ->content_is('Unauthorized');

    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( undef, undef, $cb ) = @_;
            $cb->( "Mock::SharedSecret", 'foobar' );
            fail("should have compared secret to cached secret");
            return;
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(403)
        ->content_is('Unauthorized');

    $t->app->kong_secret_cache->delete_all();

};

subtest 'authorized when given header matches kong stored secret' => sub {
    my $mock_shared_secret = Test::MockModule->new('Kong::SharedSecret');
    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( undef, undef, $cb ) = @_;
            $cb->( 'Mock::SharedSecret', 'foobar' );
        }
    );
    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(200)
        ->content_is('Hello Mojo!');

    # is( $t->app->kong_secret_cache->get('Kong-Shared-Secret'),
    #       'foobar', 'cache was set' );

    my $callback_was_called = 0;
    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( undef, undef, $cb ) = @_;
            say "in callback";
            $callback_was_called = 1;
            $cb->( "Mock::SharedSecret", 'foobar' );
            return;
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(200)
        ->content_is('Hello Mojo!');

    ok( !$callback_was_called, 'secret should have been pulled from cache' );

    $t->app->kong_secret_cache->delete_all();
};

done_testing();
