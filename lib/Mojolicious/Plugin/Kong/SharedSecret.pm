package Mojolicious::Plugin::Kong::SharedSecret;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::Kong::SharedSecret::SharedSecret;
use Cache::Memory::Simple;
use feature qw/state/;

our $VERSION = '0.01';

has defaults => sub {
    return {
        header_name   => 'Kong-Shared-Secret',
        kong_url      => 'http://localhost:8001',
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
    my $shared_secret_obj
        = Mojolicious::Plugin::Kong::SharedSecret::SharedSecret->new(
        kong_url    => $conf->{kong_url},
        header_name => $conf->{header_name}
        );
    my $r = $app->routes->under(
        sub {
            my ($c) = @_;

            my $cache = $self->_cache_object();

            my $header_secret
                = $c->req()->headers()->header( $conf->{header_name} );
            if ( not $header_secret ) {
                $c->render( text => 'Unauthorized', status => 403 );
                return;
            }

            $c->delay(
                sub {
                    my $delay         = shift;
                    my $cached_secret = $cache->get( $conf->{header_name} );
                    if ( $cached_secret and $cached_secret eq $header_secret ) {
                        $c->continue();
                        return;
                    }
                    else {
                        $shared_secret_obj->fetch_shared_secret(
                            $delay->begin() );
                    }
                    return;
                },
                sub {
                    my ( $delay, $secret, $err ) = @_;
                    $c->app->log->info($secret);
                    if ($err) {
                        $c->app->log->error( $c->dumper($err) );
                        $c->render(
                            text   => $err->{message},
                            status => $err->{code} // 500
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

  # With Options
  $self->plugin('Kong::SharedSecret', {
    kong_host => 'http://some-host.org:8001',
    header_name => 'Super-Secret',
    cache_seconds => 6000,
  });

  # Make sure this route can only be accessed when the request comes from Kong.
  $self->kong_secured_routes->get('/super-secret-route')->to(foo#bar);

=head1 DESCRIPTION

L<Mojolicious::Plugin::Kong::SharedSecret> is a L<Mojolicious> plugin.  This
plugin is meant to help secure your API to ensure incoming requests only come
from Kong.  This solution is meant to add an extra layer of security and may be
especially useful in situations where you might not be able to firewall off your
application but still want to enforce the use of Kong to access your API.

It assumes that your Kong admin API can also be secured either by Kong
itself or some other means.  How you do that is up to you ;)

=head1 OPTIONS

=head2 kong_host

URL where this plugin can access the kong cluster API. Defaults to
http://localhost:8001

=head2 header_name

Name of the header where this plugin should look for the shared secret from Kong.
Default is Kong-Shared-Secret

=head2 cache_seconds

Amount of time in seconds to cache the shared secret locally so subsequent
requests do not have to do the full handshake with kong.  Default is 10 minutes.

=head1 Helpers

This module registers the folliwing helpers:

=head2 kong_secured_routes

Returns a router for which all routes under it will return 403 unless the request
came through Kong.

=head1 METHODS

L<Mojolicious::Plugin::Kong::SharedSecret> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  $plugin->register(Mojolicious->new);

Register plugin in L<Mojolicious> application.

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<http://mojolicious.org>.

=cut
