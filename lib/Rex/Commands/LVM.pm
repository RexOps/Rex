#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::LVM - Get LVM Information

=head1 DESCRIPTION

With this module you can get information of your lvm setup.

Version <= 1.0: All these functions will not be reported.

All these functions are not idempotent.

=head1 SYNOPSIS

 use Rex::Commands::LVM;
 
 my @physical_devices = pvs;
 my @volume_groups = vgs;
 my @logical_volumes = lvs;



=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::LVM;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(pvs vgs lvs pvcreate vgcreate lvcreate vgextend);

use Rex::Helper::Run;
use Rex::Commands::Mkfs;

=head2 pvs

Get Information for all your physical volumes.

 use Data::Dumper;
 use Rex::Commands::LVM;
 
 task "lvm", sub {
   my @physical_volumes = pvs;
 
   for my $physical_volume (@physical_volumes) {
     say Dumper($physical_volume);
   }
 };

=cut

sub pvs {

  my @lines =
    i_run 'pvdisplay --units b --columns --separator "|" --noheadings',
    fail_ok   => 1,
    no_stderr => 1;
  if ( $? != 0 ) {
    die("Error running pvdisplay");
  }

  my @ret;
  for my $line (@lines) {
    chomp $line;
    $line =~ s/^\s+//g;
    my ( $phy_vol, $vol_group, $format, $attr, $psize, $pfree ) =
      split( /\|/, $line );
    $pfree =~ s/B$//;
    $psize =~ s/B$//;

    push(
      @ret,
      {
        physical_volume => $phy_vol,
        volume_group    => $vol_group,
        format          => $format,
        attributes      => $attr,
        size            => $psize,
        free            => $pfree,
      }
    );
  }

  return @ret;

}

=head2 vgs

Get Information for all your volume groups.

 use Data::Dumper;
 use Rex::Commands::LVM;
 
 task "lvm", sub {
   my @volume_groups = vgs;
 
   for my $volume_group (@volume_groups) {
     say Dumper($volume_group);
   }
 };

=cut

sub vgs {

  my ($vg) = @_;

  my $cmd =
    'vgdisplay --units b --columns --separator "|" --noheadings -o "pv_name,vg_name,vg_size,vg_free,vg_attr"';
  if ($vg) {
    $cmd .= " $vg";
  }

  my @lines = i_run $cmd, fail_ok => 1, no_stderr => 1;
  if ( $? != 0 ) {
    die("Error running vgdisplay");
  }

  my @ret;
  for my $line (@lines) {
    chomp $line;
    $line =~ s/^\s+//g;
    my ( $pv_name, $vg_name, $vg_size, $vg_free, $vg_attr ) =
      split( /\|/, $line );
    $vg_free =~ s/B$//;
    $vg_size =~ s/B$//;

    push(
      @ret,
      {
        physical_volume => $pv_name,
        volume_group    => $vg_name,
        size            => $vg_size,
        free            => $vg_free,
        attributes      => $vg_attr,
      }
    );
  }

  return @ret;

}

=head2 lvs

Get Information for all your logical volumes.

 use Data::Dumper;
 use Rex::Commands::LVM;
 
 task "lvm", sub {
   my @logical_volumes = lvs;
 
   for my $logical_volume (@logical_volumes) {
     say Dumper($logical_volume);
   }
 };

=cut

sub lvs {

  my ($vg) = @_;

  my $cmd =
    'lvdisplay --units b --columns --separator "|" -o "lv_name,vg_name,lv_attr,lv_size" --noheading';
  if ($vg) {
    $cmd .= " " . $vg;
  }

  my @lines = i_run $cmd, fail_ok => 1, no_stderr => 1;
  if ( $? != 0 ) {
    die("Error running lvdisplay");
  }

  my @ret;
  for my $line (@lines) {
    chomp $line;
    $line =~ s/^\s+//g;

    my ( $lv_name, $vg_name, $lv_attr, $lv_size ) = split( /\|/, $line );
    $lv_size =~ s/B$//;
    push(
      @ret,
      {
        name       => $lv_name,
        path       => "/dev/$vg_name/$lv_name",
        attributes => $lv_attr,
        size       => $lv_size,
      }
    );
  }

  return @ret;
}

sub pvcreate {
  my ($dev) = @_;
  my $s     = i_run "pvcreate $dev", fail_ok => 1, stderr_to_stdout => 1;
  if ( $? != 0 ) {
    die("Error creating pv.\n$s\n");
  }

  return 1;
}

sub vgcreate {
  my ( $vgname, @devices ) = @_;

  my $s = i_run "vgcreate $vgname " . join( " ", @devices ),
    fail_ok          => 1,
    stderr_to_stdout => 1;
  if ( $? != 0 ) {
    die("Error creating vg.\n$s\n");
  }

  return 1;
}

sub lvcreate {
  my ( $lvname, %option ) = @_;

  if ( !exists $option{size} || !exists $option{onvg} ) {
    die("Missing parameter size or onvg.");
  }

  unless ( $lvname =~ m/^[a-z0-9\-\._]+$/i ) {
    die("Error in lvname. Allowed characters a-z, 0-9 and _-. .");
  }

  my $size = $option{size};
  if ( $size =~ m/^[0-9]+$/ ) { $size .= "M"; }
  my $onvg = $option{onvg};

  my $s = i_run "lvcreate -n $lvname -L $size $onvg",
    fail_ok          => 1,
    stderr_to_stdout => 1;

  if ( $? != 0 ) {
    die("Error creating lv.\n$s\n");
  }

  my $lv_path = $option{onvg} . "/" . $lvname;

  mkfs "$lv_path", fstype => $option{fstype} if ( $option{fstype} );

  return $lv_path;
}

sub vgextend {
  my ( $vgname, @devices ) = @_;

  my $s = i_run "vgextend $vgname " . join( " ", @devices ),
    fail_ok          => 1,
    stderr_to_stdout => 1;

  if ( $? != 0 ) {
    die("Error extending vg.\n$s\n");
  }

  return 1;
}

1;
