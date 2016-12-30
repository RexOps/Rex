#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Inventory::Hal;

use strict;
use warnings;

use Rex::Inventory::Hal::Object;
use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Commands::Gather;
use Rex::Logger;

# VERSION

use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  $self->_read_lshal();

  return $self;
}

# get devices of $category
# like net or storage
sub get_devices_of {

  my ( $self, $cat, $rex_class ) = @_;
  my @ret;

  for my $dev ( keys %{ $self->{'__hal'}->{$cat} } ) {
    push( @ret, $self->get_object_by_cat_and_udi( $cat, $dev, $rex_class ) );
  }

  return @ret;
}

# get network devices
sub get_network_devices {

  my ($self) = @_;
  return $self->get_devices_of('net');

}

# get storage devices
sub get_storage_devices {

  my ($self) = @_;
  my $os = get_operating_system();

  if ( $os =~ m/BSD/ ) {
    return
      grep { !$_->is_cdrom && !$_->is_volume && !$_->is_floppy }
      $self->get_devices_of( 'block', 'storage' );
  }
  else {
    # default linux
    return
      grep { !$_->is_cdrom && !$_->is_floppy } $self->get_devices_of('storage');
  }

}

# get storage volumes
sub get_storage_volumes {

  my ($self) = @_;

  my $os = get_operating_system();

  if ( $os =~ m/BSD/ ) {
    return
      grep { !$_->is_cdrom && $_->is_volume && !$_->is_floppy }
      $self->get_devices_of( 'block', 'volume' );
  }
  else {
    # default linux
    return $self->get_devices_of('volume');
  }

}

# get a hal object from category and udi
sub get_object_by_cat_and_udi {
  my ( $self, $cat, $udi, $rex_class ) = @_;

  $rex_class ||= $cat;

  my $class_name = "Rex::Inventory::Hal::Object::\u$rex_class";
  eval "use $class_name";
  if ($@) {
    Rex::Logger::debug(
      "This Hal Object isn't supported yet. Falling back to Base Object.");
    $class_name = "Rex::Inventory::Hal::Object";
  }

  return $class_name->new( %{ $self->{'__hal'}->{$cat}->{$udi} },
    hal => $self );
}

# get object by udi
sub get_object_by_udi {
  my ( $self, $udi ) = @_;

  for my $cat ( keys %{ $self->{'__hal'} } ) {
    for my $dev ( keys %{ $self->{'__hal'}->{$cat} } ) {
      if ( $dev eq $udi ) {
        return $self->get_object_by_cat_and_udi( $cat, $dev );
      }
    }
  }
}

# private method to read lshal output
# you don't see that...
sub _read_lshal {

  my ($self) = @_;

  unless ( can_run "lshal" ) {
    Rex::Logger::info("No lshal available");
    die;
  }

  my @lines = i_run "lshal", fail_ok => 1;
  my %devices;
  my %tmp_devices;

  my $in_dev = 0;
  my %data;
  my $dev_name;

  for my $l (@lines) {
    chomp $l;

    if ( $l =~ m/^udi = '(.*?)'/ ) {
      $in_dev   = 1;
      $dev_name = $1;
    }

    if ( $l =~ m/^$/ ) {
      $in_dev = 0;
      unless ($dev_name) {
        %data = ();
        next;
      }
      $tmp_devices{$dev_name} = {%data};
      %data = ();
    }

    if ($in_dev) {
      my ( $key, $val ) = split( / = /, $l, 2 );
      $key =~ s/^\s+//;
      $key =~ s/^'|'$//g;
      $val =~ s/\(.*?\)$//;
      $val =~ s/^\s+//;
      $val =~ s/\s+$//;
      $val =~ s/^'|'$//g;
      $data{$key} = $self->_parse_hal_string($val);
    }

  }

  for my $dev ( keys %tmp_devices ) {

    my $s_key = $tmp_devices{$dev}->{"info.subsystem"}
      || $tmp_devices{$dev}->{"linux.subsystem"};
    $s_key ||= $tmp_devices{$dev}->{"info.category"};

    if ( !$s_key ) {

      #print Dumper($tmp_devices{$dev});
      next;
    }

    if ( $s_key =~ m/\./ ) {
      ($s_key) = split( /\./, $s_key );
    }

    if ( !exists $devices{$s_key} ) {
      $devices{$s_key} = {};
    }

    $devices{$s_key}->{$dev} = $tmp_devices{$dev};

  }

  $self->{'__hal'} = \%devices;

}

sub _parse_hal_string {

  my ( $self, $line ) = @_;

  if ( $line =~ m/^\{.*\}$/ ) {
    $line =~ s/^\{/[/;
    $line =~ s/\}$/]/;

    return eval $line;
  }

  return $line;

}

1;
