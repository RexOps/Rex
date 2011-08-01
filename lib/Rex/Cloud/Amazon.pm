#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

#
# Some of the code is based on Net::Amazon::EC2
#
   
package Rex::Cloud::Amazon;
   
use strict;
use warnings;

use Rex::Logger;

use LWP::UserAgent;
use MIME::Base64 qw(encode_base64 decode_base64);
use Digest::HMAC_SHA1;
use HTTP::Date qw(time2isoz);

use XML::Simple;

use Data::Dumper;


sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   #$self->{"__version"} = "2009-11-30";
   $self->{"__version"} = "2011-05-15";
   $self->{"__signature_version"} = 1;
   $self->{"__endpoint_url"} = "http://us-east-1.ec2.amazonaws.com";

   return $self;
}

sub set_auth {
   my ($self, $access_key, $secret_access_key) = @_;

   $self->{"__access_key"} = $access_key;
   $self->{"__secret_access_key"} = $secret_access_key;
}

sub set_endpoint {
   my ($self, $endpoint) = @_;
   $self->{'__endpoint_url'} = "http://$endpoint";
}

sub timestamp {
   my $t = time2isoz();
   chop($t);
   $t .= ".000Z";
   $t =~ s/\s+/T/g;
   return $t;
}

sub run_instance {
   my ($self, %data) = @_;

   my $xml = $self->_request("RunInstances", 
               ImageId  => $data{"image_id"},
               MinCount => 1,
               MaxCount => 1,
               InstanceType => $data{"type"} || "m1.small");

   my $ref = XMLin($xml);

   if(exists $data{"name"}) {
      $self->add_tag(id => $ref->{"instancesSet"}->{"item"}->{"instanceId"},
                     name => "Name",
                     value => $data{"name"});
   }

}

sub terminate_instance {
   my ($self, $id) = @_;

   $self->_request("TerminateInstances",
               "InstanceId.1" => $id);
}

sub stop_instance {
   my ($self, $id) = @_;

   $self->_request("StopInstances",
               "InstanceId.1" => $id);
}

sub add_tag {
   my ($self, %data) = @_;

   $self->_request("CreateTags",
               "ResourceId.1" => $data{"id"},
               "Tag.1.Key"    => $data{"name"},
               "Tag.1.Value"  => $data{"value"});
}

sub list_running_instances {
   my ($self) = @_;

   my @ret;

   my $xml = $self->_request("DescribeInstances");
   my $ref = XMLin($xml);

   for my $instance_set (@{$ref->{"reservationSet"}->{"item"}}) {
      push(@ret, {
         ip => $instance_set->{"instancesSet"}->{"item"}->{"ipAddress"},
         id => $instance_set->{"instancesSet"}->{"item"}->{"instanceId"},
         architecture => $instance_set->{"instancesSet"}->{"item"}->{"architecture"},
         type => $instance_set->{"instancesSet"}->{"item"}->{"instanceType"},
         dns_name => $instance_set->{"instancesSet"}->{"item"}->{"dnsName"},
         state => $instance_set->{"instancesSet"}->{"item"}->{"instanceState"}->{"name"},
         launch_time => $instance_set->{"instancesSet"}->{"item"}->{"launchTime"},
         name => $instance_set->{"instancesSet"}->{"item"}->{"tagSet"}->{"item"}->{"value"},
      });
   }

   return @ret;
}

sub get_regions {
   my ($self) = @_;

   my $content = $self->_request("DescribeRegions");
   my %items = ($content =~ m/<regionName>([^<]+)<\/regionName>\s+<regionEndpoint>([^<]+)<\/regionEndpoint>/gsim);

   return %items;
}

sub _request {
   my ($self, $action, %args) = @_;

   my $ua = LWP::UserAgent->new;
   my %param = $self->_sign($action, %args);

   my $res = $ua->post($self->{'__endpoint_url'}, \%param);

   if($res->code >= 500) {
      Rex::Logger::info("Error on request");
   }

   else {
      return $res->content;
   }
}

sub _sign {
   my ($self, $action, %args) = @_;  

   my %sign_hash = (
      AWSAccessKeyId   => $self->{"__access_key"},
      Action           => $action,
      Timestamp        => $self->timestamp(),
      Version          => $self->{"__version"},
      SignatureVersion => $self->{"__signature_version"},
      %args
   );

   my $sign_this;
   foreach my $key (sort { lc($a) cmp lc($b) } keys %sign_hash) {
      $sign_this .= $key . $sign_hash{$key};
   }

   Rex::Logger::debug("Signed: $sign_this");

   my $encoded = $self->_hash($sign_this);

   my %params = (
      Action            => $action,
      SignatureVersion  => $self->{"__signature_version"},
      AWSAccessKeyId    => $self->{"__access_key"},
      Timestamp         => $self->timestamp(),
      Version           => $self->{"__version"},
      Signature         => $encoded,
      %args
   );

   return %params;
}

sub _hash {
   my ($self, $query_string) = @_;

   my $hashed = Digest::HMAC_SHA1->new($self->{"__secret_access_key"});
   $hashed->add($query_string);

   return encode_base64($hashed->digest, "");
}



1;
