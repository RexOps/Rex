#
# (c) Ferenc Erki <erkiferenc@gmail.com>
#

package Rex::Cloud::OpenStack;

use base 'Rex::Cloud::Base';

use HTTP::Request::Common qw(:DEFAULT DELETE);
use JSON::XS;
use LWP::UserAgent;

sub new {
    my $that  = shift;
    my $proto = ref($that) || $that;
    my $self  = {@_};

    bless( $self, $proto );

    $self->{_agent} = LWP::UserAgent->new;

    return $self;
}

sub set_auth {
    my ( $self, %auth ) = @_;

    $self->{auth} = \%auth;
}

sub _authenticate {
    my $self = shift;

    my $auth_data = {
        auth => {
            tenantName => $self->{auth}{tenantName} || '',
            passwordCredentials => {
                username => $self->{auth}{username},
                password => $self->{auth}{password},
            }
        }
    };

    my $request = POST $self->{__endpoint} . '/tokens',
        Content_Type => 'application/json',
        Content      => encode_json($auth_data);

    my $response = $self->{_agent}->request($request);

    my $content = decode_json( $response->content );

    $self->{auth}{tokenId} = $content->{access}{token}{id};

    $self->{_agent}
        ->default_header( 'X-Auth-Token' => $self->{auth}{tokenId} );

    $self->{_catalog} = $content->{access}{serviceCatalog};
}

sub get_nova_url {
    my $self = shift;

    $self->_authenticate unless $self->{auth}{tokenId};

    my @nova_services
        = grep { $_->{type} eq 'compute' } @{ $self->{_catalog} };
    return $nova_services[0]{endpoints}[0]{publicURL};
}

sub run_instance {
    my ( $self, %data ) = @_;
    my $nova_url     = $self->get_nova_url;
    my $request_data = {
        server => {
            flavorRef => $data{plan_id},
            imageRef  => $data{image_id},
            name      => $data{name},
        }
    };

    my $request = POST $nova_url . '/servers',
        Content_Type => 'application/json',
        Content      => encode_json($request_data);

    my $response = $self->{_agent}->request($request);
}

sub terminate_instance {
    my ( $self, %data ) = @_;
    my $nova_url = $self->get_nova_url;

    my $request = DELETE $nova_url . '/servers/' . $data{instance_id};

    my $respone = $self->{_agent}->request($request);
}

1;
