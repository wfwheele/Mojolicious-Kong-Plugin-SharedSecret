package Mojolicious::Plugin::Kong::SharedSecret::SharedSecret;
use Mojo::Base -base;
use Mojolicious::Plugin::Kong::SharedSecret::Kong;
use Carp qw/confess/;
use Data::Dumper;

has 'kong_url' => sub {
    return 'http://localhost:8001';
};

has 'header_name' => sub {
    return 'Kong-Shared-Secret';
};

has _kong => sub {
    my $self = shift;
    my $kong = Mojolicious::Plugin::Kong::SharedSecret::Kong->new()
        ->kong_host( $self->kong_url() );
    return $kong;
};

sub fetch_shared_secret {
    my ( $self, $cb ) = @_;
    my $kong = $self->_kong();
    $kong->fetch_plugins( { name => 'request-transformer' },
        $self->_handle_response($cb) );
    return;
}

sub _handle_response {
    my ( $self, $cb ) = @_;
    my $header_name = $self->header_name();
    return sub {
        my ( $kong, $plugins, $err ) = @_;
        my $secret;
        if ($err) {
            $cb->( $self, undef, $err );
            return;
        }
        my $headers_map
            = $self->_map_headers( $self->_extract_headers($plugins) );
        $secret = $headers_map->{$header_name};

        if ( not defined $secret ) {
            $cb->(
                $self, undef,
                {   message =>
                        'Could not get secret from Kong, make sure header_name is configured correctly and that request-transformer plugin is enabled on kong cluster for your API'
                }
            );
            return;
        }
        $cb->( $self, $secret );
        return;
    };
}

sub _extract_headers {
    my ( $self, $plugins ) = @_;
    my @headers;
    for my $plugin ( @{$plugins} ) {
        push @headers, @{ $plugin->{config}->{add}->{headers} };
    }
    return \@headers;
}

sub _map_headers {
    my ( $self, $headers ) = @_;
    my %map;
    for my $header ( @{$headers} ) {
        my ( $key, $value ) = split /:/, $header;
        $map{$key} = $value;
    }
    return \%map;
}

1;

__END__

=head1 NAME

Kong::SharedSecret

=head1 DESCRIPTION

This module turns a call to the /plugins route of Kong admin API and fetches
the shared secret for L<Mojolicious::Plugin::Kong::SharedSecret> .  It probably
shouldn't be used outside the plugin and it's API is subject to change without
notice.

=head1 METHODS

=head2 fetch_shared_secret

  $shared_secret->fetch_shared_secret($kong_url, $header_name, sub{
    my ($class, $shared_secret, $error) = @_;
    # have fun
  });

Takes in the url to reach the kong cluster at and header in which shared secret
can be found, and a callback as params.

=cut
