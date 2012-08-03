#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Connection::HTTP;
   
use strict;
use warnings;

use Rex::Interface::Connection::Base;
use LWP::UserAgent;
use JSON::XS;
use Data::Dumper;

use base qw(Rex::Interface::Connection::Base);

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $that->SUPER::new(@_);

   bless($self, $proto);

   return $self;
}

sub error { };
sub connect {
   my ($self, %option) = @_;
   my ($user, $pass, $server, $port, $timeout);

   $user    = $option{user};
   $pass    = $option{password};
   $server  = $option{server};
   $port    = $option{port} || 80;
   $timeout = $option{timeout};

   $self->{server} = $server;
   $self->{port} = $port;

   if($server =~ m/([^:]+):(\d+)/) {
      $server = $self->{server} = $1;
      $port   = $self->{port}   = $2;
   }

   $self->{__user} = $user;
   $self->{__pass} = $pass;

   if( ! Rex::Config->has_user && Rex::Config->get_ssh_config_username(server => $server) ) {
      $user = Rex::Config->get_ssh_config_username(server => $server);
   }

   $self->{ua} = LWP::UserAgent->new;
   $self->ua->credentials(
      "$server:$port",
      "Rex::Endpoint::HTTP",
      $user => $pass,
   );

   my $resp = $self->post("/login");
   if($resp->{ok}) {
      Rex::Logger::info("Connected to $server, trying to authenticate.");
   }
   else {
      Rex::Logger::info("Can't connect to $server", "warn");
      $self->{connected} = 0;
      return;
   }

   Rex::Logger::info("Connecting to $server:$port (" . $user . ")");

}

sub disconnect { };
sub get_connection_object { my ($self) = @_; return $self; };
sub get_fs_connection_object { my ($self) = @_; return $self; };
sub is_connected { return 1; };
sub is_authenticated { return 1; };

sub exec {
   my ($self, $cmd) = @_;
}

sub ua { shift->{ua}; }

sub upload {
   my ($self, $data) = @_;

   my $res = $self->ua->post("http://" . $self->{server} . ":" . $self->{port} . "/fs/upload",
               Content_Type => "multipart/form-data",
               Content => $data);

   if($res->is_success) {
      return decode_json($res->decoded_content);
   }
   else {
      die("Error requesting /fs/upload.");
   }
}

sub post {
   my ($self, $service, $data, $header) = @_;

   $header ||= {};
   $data ||= {};

   if(! ref($data)) {
      die("Invalid 2nd argument. must be arrayRef or hashRef!\npost(\$service, \$ref)");
   }

   my $res = $self->ua->post("http://" . $self->{server} . ":" . $self->{port} . "$service", %{$header}, Content => encode_json($data));

   if($res->is_success) {
      return decode_json($res->decoded_content);
   }
   else {
      die("Error requesting $service.");
   }

}

sub get {
   my ($self, $service) = @_;

   my $res = $self->ua->get("http://" . $self->{server} . ":" . $self->{port} . "$service");

   if($res->is_success) {
      return decode_json($res->decoded_content);
   }
   else {
      die("Error requesting $service.");
   }

}

sub get_connection_type { return "HTTP"; }

1;
