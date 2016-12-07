use Mojo::Base -strict;
use Test::More;
use Test::MockModule;
use Data::Dumper;

BEGIN {
    use_ok('Kong::SharedSecret')
        || BAIL_OUT('could not use Kong::SharedSecret');
}

my $mockkong = Test::MockModule->new('Kong');
$mockkong->mock(
    'fetch_plugins',
    sub {
        my ( $kong, $filters, $cb ) = @_;
        $cb->(
            $kong,
            [   {   config =>
                        { add => { headers => ['Kong-Shared-Secret:foobar'] } }
                }
            ]
        );
    }
);

Kong::SharedSecret::fetch_shared_secret(
    'http://localhost:8001',
    'Kong-Shared-Secret',
    sub {
        my ( $class, $secret, $err ) = @_;
        ok( !defined $err, 'err is not defined on success' );
        is( $secret, 'foobar', 'successfully pulled secret from kong' );
    }
);

$mockkong->unmock_all();

$mockkong->mock(
    'fetch_plugins' => sub {
        my ( $kong, $filters, $cb ) = @_;
        $cb->(
            $kong, undef, { message => 'Internal Server Error', code => 500 }
        );
        return;
    }
);

Kong::SharedSecret::fetch_shared_secret(
    'http://localhost:8001',
    'Kong-Shared-Secret',
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

done_testing();
