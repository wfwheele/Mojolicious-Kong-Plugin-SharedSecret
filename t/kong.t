use Mojo::Base -strict;
use Test::More;
use Test::MockModule;

BEGIN {
    use_ok('Mojolicious::Plugin::Kong::SharedSecret::Kong')
        || BAIL_OUT('could not use Kong module');
}

my $module = 'Mojolicious::Plugin::Kong::SharedSecret::Kong';

my $kong = $module->new();

can_ok( $kong, 'kong_host' );

is( $kong->kong_host(), 'http://localhost:8001',
    'default kong_host is localhost:8001' );

$kong->kong_host('http://foobar.org');
is( $kong->kong_host(), 'http://foobar.org', 'kong host set successfully' );

subtest 'fetch_plugins' => sub {
    subtest 'success' => sub {
        ### setup
        my $kong = $module->new();
        $kong->kong_host('http://foobar.org:8001');
        my $mockua = Test::MockModule->new('Mojo::UserAgent');
        my $url_to_test;
        $mockua->mock(
            'get',
            sub {
                my ( $self, $url, $cb ) = @_;
                my $tx = $self->build_tx( GET => $url );
                $url_to_test = $url;
                $tx->res()
                    ->body(
                    q|{"data":[{"name":"request-transformer", "config":{"add":{"headers":["Kong-Shared-Secret:s3cr3t"]}}}]}|
                    );
                $tx->res->code(200);
                $cb->( $self, $tx );
            }
        );
        ### tests
        $kong->fetch_plugins(
            { name => 'request-transformer' },
            sub {
                my ( $k, $plugins, $err ) = @_;
                ok( !defined $err, 'error not defined on success' );
                is( ref $plugins, 'ARRAY', 'returns an array ref' );
            }
        );
        is( $url_to_test->query->param('name'),
            'request-transformer', 'query params built' );
        is( $url_to_test->host(), 'foobar.org', 'correct kong host used' );
        is( $url_to_test->port(), '8001',       'correct kong port used' );
        is( $url_to_test->path()->to_string(),
            '/plugins', 'correct api path used' );
    };

    subtest 'error' => sub {
        ### setup
        my $kong   = $module->new();
        my $mockua = Test::MockModule->new('Mojo::UserAgent');
        $mockua->mock(
            'get',
            sub {
                my ( $self, $url, $cb ) = @_;
                my $tx = $self->build_tx( GET => $url );
                $tx->res()->code(500);
                $tx->res()
                    ->error(
                    { code => 500, message => 'Internal Server Error' } );
                $cb->( $self, $tx );
            }
        );
        ### tests
        $kong->fetch_plugins(
            { name => 'request-transformer' },
            sub {
                my ( $k, $plugins, $err ) = @_;
                ok( defined $err, 'err is defined when something goes wrong' );
            }
        );
    };

};

done_testing();

1;
