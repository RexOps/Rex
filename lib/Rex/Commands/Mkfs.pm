
=head1 NAME

Rex::Commands::Mkfs - Create filesystems

=head1 DESCRIPTION

With this module you can create filesystems on existing partitions and logical volumes.

=head1 SYNOPSIS

 use Rex::Commands::Mkfs;

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Mkfs;

use warnings;
use strict;

# VERSION

require Rex::Exporter;
use base qw(Rex::Exporter);
use vars qw(@EXPORT);

@EXPORT = qw(mkfs);

use Rex::Helper::Run;
use Rex::Commands::Run;
use Carp;

=head2 mkfs($devname, %option)

Create a filesystem on device $devname.

 mkfs "sda1",
   fstype => "ext2",
   label  => "mydisk";

 mkfs "sda2",
   fstype => "swap";

=cut

sub mkfs {
  my ( $devname, %option ) = @_;

  if ( $devname !~ m/^\// ) {
    $devname = "/dev/$devname";
  }

  my $add_opts = "";

  unless ( exists $option{fstype} && defined $option{fstype} ) {
    croak("Missing or undefined fstype.");
  }

  if ( grep { $option{fstype} eq $_ } ( "non-fs", "none", "" ) ) {
    Rex::Logger::debug("Skip creating a filesystem of type '$option{fstype}'");
    return;
  }

  if ( ( exists $option{label} && $option{label} )
    || ( exists $option{lable} && $option{lable} ) )
  {
    my $label = $option{label} || $option{lable};
    $add_opts .= " -L $label ";
  }

  if ( $option{fstype} eq "swap" ) {
    Rex::Logger::info("Creating swap space on $devname");
    i_run "mkswap $add_opts -f $devname";
  }
  elsif ( can_run("mkfs.$option{fstype}") ) {
    Rex::Logger::info("Creating filesystem $option{fstype} on $devname");

    i_run "mkfs.$option{fstype} $add_opts $devname";
  }

  return;
}

1;
