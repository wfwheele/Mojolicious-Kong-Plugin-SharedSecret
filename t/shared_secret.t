use Mojo::Base -strict;
use Test::More;
use Test::MockModule;
use Data::Dumper;

BEGIN {
    use_ok('Mojolicious::Plugin::Kong::SharedSecret::SharedSecret')
        || BAIL_OUT('could not use Kong::SharedSecret');
}

my $module = 'Mojolicious::Plugin::Kong::SharedSecret::SharedSecret';
my $kong   = 'Mojolicious::Plugin::Kong::SharedSecret::Kong';

subtest 'attributes' => sub {
    my $shared_secret = $module->new();
    is( $shared_secret->kong_url(),
        'http://localhost:8001', 'default kong url is http://localhost:8001' );
    is( $shared_secret->header_name(),
        'Kong-Shared-Secret', 'default header name is Kong-Shared-Secret' );
    $shared_secret = $module->new(
        kong_url    => 'http://foo.bar.org:8001',
        header_name => 'Foobar'
    );
    is( $shared_secret->kong_url(),
        'http://foo.bar.org:8001', 'kong_url can be set from constructor' );
    is( $shared_secret->header_name(),
        'Foobar', 'header_name can be set from constructor' );
    is( $shared_secret->_kong()->kong_host(),
        'http://foo.bar.org:8001', 'url gets set in Kong object' );
};

subtest 'test success' => sub {
    my $mockkong      = Test::MockModule->new($kong);
    my $shared_secret = $module->new();
    my $filter_to_test;
    $mockkong->mock(
        'fetch_plugins',
        sub {
            my ( $kong, $filters, $cb ) = @_;
            $filter_to_test = $filters;
            $cb->(
                $kong,
                [   {   config => {
                            add => { headers => ['Kong-Shared-Secret:foobar'] }
                        }
                    }
                ]
            );
        }
    );

    $shared_secret->fetch_shared_secret(
        sub {
            my ( $class, $secret, $err ) = @_;
            ok( !defined $err, 'err is not defined on success' );
            is( $secret, 'foobar', 'successfully pulled secret from kong' );
            is_deeply(
                $filter_to_test,
                { name => 'request-transformer' },
                'correct filters passed'
            );
        }
    );

    $mockkong->unmock_all();
};

subtest 'test error' => sub {
    my $mockkong      = Test::MockModule->new($kong);
    my $shared_secret = $module->new();
    $mockkong->mock(
        'fetch_plugins' => sub {
            my ( $kong, $filters, $cb ) = @_;
            $cb->(
                $kong, undef,
                { message => 'Internal Server Error', code => 500 }
            );
            return;
        }
    );

    $shared_secret->fetch_shared_secret(
        sub {
            my ( $class, $secret, $err ) = @_;
            ok( !defined $secret, 'secret not defined on error' );
            is_deeply(
                $err,
                { message => 'Internal Server Error', code => 500 },
                'err object has message and code'
            );
        }
    );
    $mockkong->unmock_all();
};

subtest 'err when Kong not configured correctly' => sub {
    my $mockkong      = Test::MockModule->new($kong);
    my $shared_secret = $module->new();
    $mockkong->mock(
        'fetch_plugins' => sub {
            my ( $kong, $filters, $cb ) = @_;
            $cb->( $kong, [] );
            return;
        }
    );
    $shared_secret->fetch_shared_secret(
        sub {
            my ( $kong, $secret, $err ) = @_;
            ok( !defined $secret,
                'secret not defined when kong is not configured correctly' );
            is( $err->{message},
                'Could not get secret from Kong, make sure header_name is configured correctly and that request-transformer plugin is enabled on kong cluster for your API',
                'helpful message displayed when not configured correctly'
            );
        }
    );
};

done_testing();
