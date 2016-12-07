package Mojolicious::Plugin::Kong::SharedSecret;
use Mojo::Base 'Mojolicious::Plugin';
use Kong::SharedSecret;
use Cache::Memory::Simple;
use feature qw/state/;

our $VERSION = '0.01';

has defaults => sub {
    return {
        header_name   => 'Kong-Shared-Secret',
        kong_host     => 'http://localhost:8001',
        cache_seconds => ( 60 * 10 ),
    };
};

sub _cache_object {
    state $cache = Cache::Memory::Simple->new();
    return $cache;
}

sub register {
    my ( $self, $app, $conf_arg ) = @_;
    my $conf = $self->_merge_default_conf($conf_arg);

    my $r = $app->routes->under(
        sub {
            my ($c) = @_;

            my $cache = $self->_cache_object();

            #get secret from header
            my $header_secret
                = $c->req()->headers()->header( $conf->{header_name} );
            $c->render( text => 'Unauthorized', status => 403 )
                if not $header_secret;
            my $cached_secret = $cache->get( $conf->{header_name} );
            if ($cached_secret) {
                say "cached_secret: $cached_secret";
                my $return;
                if ( $cached_secret eq $header_secret ) {
                    $return = 1;
                }
                else {
                    $c->render( text => 'Unauthorized', status => 403 );
                }
                return $return;
            }

            #fetch secret from kong
            $c->delay(
                sub {
                    my $delay = shift;
                    Kong::SharedSecret::fetch_shared_secret( $conf->{kong_url},
                        $conf->{header_name}, $delay->begin() );
                    return;
                },
                sub {
                    #compare
                    my ( $delay, $secret, $err ) = @_;
                    if ($err) {
                        $c->render(
                            text   => $err->{message},
                            status => $err->{code}
                        );
                    }
                    else {
                        say "we are setting cache";
                        $cache->set( $conf->{header_name}, $secret,
                            $conf->{cache_seconds} );
                        if ( $header_secret ne $secret ) {
                            $c->render( text => 'Unauthorized', status => 403 );
                        }
                        else {
                            $c->continue();
                        }
                    }
                }
            );
            return;
        }
    );
    $app->helper(
        'kong_secured_routes' => sub {
            return $r;
        }
    );

    $app->helper(
        'kong_secret_cache' => sub {
            return $self->_cache_object();
        }
    );
}

sub _merge_default_conf {
    my ( $self, $conf ) = @_;
    return { %{ $self->defaults() }, %{$conf} };
}

1;
__END__

=encoding utf8

=head1 NAME

Mojolicious::Plugin::Kong::SharedSecret - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('Kong::SharedSecret');

  # Mojolicious::Lite
  plugin 'Kong::SharedSecret';

=head1 DESCRIPTION

L<Mojolicious::Plugin::Kong::SharedSecret> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::Kong::SharedSecret> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
