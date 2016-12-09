use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use Test::MockModule;

plugin 'Kong::SharedSecret';

my $kong_secured_routes = app->kong_secured_routes();
my $kong_shared_secret
    = 'Mojolicious::Plugin::Kong::SharedSecret::SharedSecret';

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
    my $mock_shared_secret = Test::MockModule->new($kong_shared_secret);
    $mock_shared_secret->mock(
        'fetch_shared_secret',
        sub {
            my ( $self, $cb ) = @_;
            $cb->( $self, 'barfoo' );
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(403)
        ->content_is('Unauthorized');

    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( $self, $cb ) = @_;
            $cb->( $self, 'foobar' );
            fail("should have compared secret to cached secret");
            return;
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(403)
        ->content_is('Unauthorized');

    $t->app->kong_secret_cache->delete_all();

};

subtest 'authorized when given header matches kong stored secret' => sub {
    my $mock_shared_secret = Test::MockModule->new($kong_shared_secret);
    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( $self, $cb ) = @_;
            $cb->( $self, 'foobar' );
        }
    );
    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(200)
        ->content_is('Hello Mojo!');

    my $callback_was_called = 0;
    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( $self, $cb ) = @_;
            say "in callback";
            $callback_was_called = 1;
            $cb->( $self, 'barbar' );
            return;
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(200)
        ->content_is('Hello Mojo!');

    ok( !$callback_was_called, 'secret should have been pulled from cache' );

    $t->app->kong_secret_cache->delete_all();
};

subtest 'render err if err' => sub {
    my $mock_shared_secret = Test::MockModule->new($kong_shared_secret);
    $mock_shared_secret->mock(
        'fetch_shared_secret',
        sub {
            my ( $self, $cb ) = @_;
            $cb->( $self, undef, { message => 'some crazy stuff went down' } );
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(500)
        ->content_is('some crazy stuff went down');

    $t->app->kong_secret_cache->delete_all();

    $mock_shared_secret->mock(
        'fetch_shared_secret' => sub {
            my ( $self, $cb ) = @_;
            $cb->(
                $self, undef, { message => 'danger! high voltage', code => 403 }
            );
            return;
        }
    );

    $t->get_ok( '/' => { 'Kong-Shared-Secret' => 'foobar' } )->status_is(403)
        ->content_is('danger! high voltage');

    $t->app->kong_secret_cache->delete_all();
};

done_testing();
