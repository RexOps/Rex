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
use Rex::Cloud::Base;

use base qw(Rex::Cloud::Base);

use LWP::UserAgent;
use MIME::Base64 qw(encode_base64 decode_base64);
use Digest::HMAC_SHA1;
use HTTP::Date qw(time2isoz);

require XML::Simple;

use Data::Dumper;


sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   #$self->{"__version"} = "2009-11-30";
   $self->{"__version"} = "2011-05-15";
   $self->{"__signature_version"} = 1;
   $self->{"__endpoint"} = "us-east-1.ec2.amazonaws.com";

   Rex::Logger::debug("Creating new Amazon Object, with endpoint: " . $self->{"__endpoint"});
   Rex::Logger::debug("Using API Version: " . $self->{"__version"});

   return $self;
}

sub set_auth {
   my ($self, $access_key, $secret_access_key) = @_;

   $self->{"__access_key"} = $access_key;
   $self->{"__secret_access_key"} = $secret_access_key;
}

sub set_endpoint {
   my ($self, $endpoint) = @_;
   Rex::Logger::debug("Setting new endpoint to $endpoint");
   $self->{'__endpoint'} = $endpoint;
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

   Rex::Logger::debug("Trying to start a new Amazon instance with data:");
   Rex::Logger::debug("   $_ -> " . ($data{$_}?$data{$_}:"undef")) for keys %data;

   my $xml = $self->_request("RunInstances", 
               ImageId  => $data{"image_id"},
               MinCount => 1,
               MaxCount => 1,
               KeyName  => $data{"key"},
               InstanceType => $data{"type"} || "m1.small",
               "Placement.AvailabilityZone" => $data{"zone"} || "");

   my $ref = $self->_xml($xml);

   if(exists $data{"name"}) {
      $self->add_tag(id => $ref->{"instancesSet"}->{"item"}->{"instanceId"},
                     name => "Name",
                     value => $data{"name"});
   }

   my ($info) = grep { $_->{"id"} eq $ref->{"instancesSet"}->{"item"}->{"instanceId"} } $self->list_instances();

   while($info->{"state"} ne "running") {
      Rex::Logger::debug("Waiting for instance to be created...");
      ($info) = grep { $_->{"id"} eq $ref->{"instancesSet"}->{"item"}->{"instanceId"} } $self->list_instances();
      sleep 1;
   }

   if(exists $data{"volume"}) {
      $self->attach_volume(
         volume_id => $data{"volume"},
         instance_id => $ref->{"instancesSet"}->{"item"}->{"instanceId"},
         name => "/dev/sdh", # default for new instances
      );
   }

   return $info;
}

sub attach_volume {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to attach a new volume");

   $self->_request("AttachVolume", 
      VolumeId => $data{"volume_id"},
      InstanceId => $data{"instance_id"},
      Device => $data{"name"} || "/dev/sdh");
}

sub detach_volume {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to detach a volume");

   $self->_request("DetachVolume",
         VolumeId => $data{"volume_id"},
      );
}

sub delete_volume {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to delete a volume");

   $self->_request("DeleteVolume", 
      VolumeId => $data{"volume_id"},
   );
}

sub terminate_instance {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to terminate an instance");

   $self->_request("TerminateInstances",
               "InstanceId.1" => $data{"instance_id"});
}

sub start_instance {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to start an instance");

   $self->_request("StartInstances",
               "InstanceId.1" => $data{instance_id});
}

sub stop_instance {
   my ($self, %data) = @_;

   Rex::Logger::debug("Trying to stop an instance");

   $self->_request("StopInstances",
               "InstanceId.1" => $data{instance_id});
}

sub add_tag {
   my ($self, %data) = @_;

   Rex::Logger::debug("Adding a new tag: " . $data{id} . " -> " . $data{name} .  " -> " . $data{value});

   $self->_request("CreateTags",
               "ResourceId.1" => $data{"id"},
               "Tag.1.Key"    => $data{"name"},
               "Tag.1.Value"  => $data{"value"});
}

sub create_volume {
   my ($self, %data) = @_;

   Rex::Logger::debug("Creating a new volume");

   my $xml = $self->_request("CreateVolume", 
               "Size" => $data{"size"} || 1,
               "AvailabilityZone" => $data{"zone"},
               );

   my $ref = $self->_xml($xml);

   return $ref->{"volumeId"};

   my ($info) = grep { $_->{"id"} eq $ref->{"volumeId"} } $self->list_volumes();

   while($info->{"status"} ne "available") {
      Rex::Logger::debug("Waiting for volume to become ready...");
      ($info) = grep { $_->{"id"} eq $ref->{"volumeId"} } $self->list_volumes();
      sleep 1;
   }

}

sub list_volumes {
   my ($self) = @_;

   my $xml = $self->_request("DescribeVolumes");
   my $ref = $self->_xml($xml);

   return unless($ref);
   return unless(exists $ref->{"volumeSet"}->{"item"});
   if(ref($ref->{"volumeSet"}->{"item"}) eq "HASH") {
      $ref->{"volumeSet"}->{"item"} = [ $ref->{"volumeSet"}->{"item"} ];
   }

   my @volumes;
   for my $vol (@{$ref->{"volumeSet"}->{"item"}}) {
      push(@volumes, {
         id => $vol->{"volumeId"},
         status => $vol->{"status"},
         zone => $vol->{"availabilityZone"},
         size => $vol->{"size"},
         attached_to => $vol->{"attachmentSet"}->{"item"}->{"instanceId"},
      });
   }

   return @volumes;
}

sub list_instances {
   my ($self) = @_;

   my @ret;

   my $xml = $self->_request("DescribeInstances");
   my $ref = $self->_xml($xml);

   return unless($ref);
   return unless(exists $ref->{"reservationSet"});
   return unless(exists $ref->{"reservationSet"}->{"item"});

   if(ref $ref->{"reservationSet"}->{"item"} eq "HASH") {
      # if only one instance is returned, turn it to an array
      $ref->{"reservationSet"}->{"item"} = [ $ref->{"reservationSet"}->{"item"} ];
   }

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

sub list_running_instances {
   my ($self) = @_;

   return grep { $_->{"state"} eq "running" } $self->list_instances();
}

sub get_regions {
   my ($self) = @_;

   my $content = $self->_request("DescribeRegions");
   my %items = ($content =~ m/<regionName>([^<]+)<\/regionName>\s+<regionEndpoint>([^<]+)<\/regionEndpoint>/gsim);

   return %items;
}

sub get_availability_zones {
   my ($self) = @_;

   my $xml = $self->_request("DescribeAvailabilityZones");
   my $ref = $self->_xml($xml);

   my @zones;
   for my $item (@{$ref->{"availabilityZoneInfo"}->{"item"}}) {
      push(@zones, {
         zone_name => $item->{"zoneName"},
         region_name => $item->{"regionName"},
         zone_state => $item->{"zoneState"},
      });
   }

   return @zones;
}

sub _request {
   my ($self, $action, %args) = @_;

   my $ua = LWP::UserAgent->new;
   my %param = $self->_sign($action, %args);

   Rex::Logger::debug("Sending request to: http://" . $self->{'__endpoint'});
   Rex::Logger::debug("   $_ -> " . $param{$_}) for keys %param;

   my $res = $ua->post("http://" . $self->{'__endpoint'}, \%param);

   if($res->code >= 500) {
      Rex::Logger::info("Error on request", "warn");
      Rex::Logger::debug($res->content);
      return;
   }

   else {
      my $ret;
      eval {
         no warnings;
         $ret = $res->content;
         Rex::Logger::debug($ret);
         use warnings;
      };

      return $ret;
   }
}

sub _sign {
   my ($self, $action, %o_args) = @_;  

   my %args;
   for my $key (keys %o_args) {
      next unless $key;
      next unless $o_args{$key};

      $args{$key} = $o_args{$key};
   }

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

sub _xml {
   my ($self, $xml) = @_;

   my $x = XML::Simple->new;
   my $res = $x->XMLin($xml);
   if(defined $res->{"Errors"}) {
      if(ref($res->{"Errors"}) ne "ARRAY") {
         $res->{"Errors"} = [ $res->{"Errors"} ];
      }

      my @error_msg = ();
      for my $error (@{$res->{"Errors"}}) {
         push(@error_msg, $error->{"Error"}->{"Message"} . " (Code: " . $error->{"Error"}->{"Code"} . ")");
      }

      die(join("\n", @error_msg));
   }

   return $res;
}


1;
