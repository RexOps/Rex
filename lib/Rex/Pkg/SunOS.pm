#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::SunOS;

use strict;
use warnings;

# VERSION

use Rex::Helper::Run;
use Rex::Commands::File;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {};

  return $self;
}

sub update {
  my ( $self, $pkg, $option ) = @_;

  my $version = $option->{'version'} || '';

  Rex::Logger::debug("Version option not supported.");
  Rex::Logger::debug("Installing $pkg / $version");

  my $cmd = "pkgadd ";

  if ( !exists $option->{"source"} ) {
    die("You have to specify the source.");
  }

  $cmd .= " -a " . $option->{"adminfile"}    if ( $option->{"adminfile"} );
  $cmd .= " -r " . $option->{"responsefile"} if ( $option->{"responsefile"} );

  $cmd .= " -d " . $option->{"source"};
  $cmd .= " -n " . $pkg;

  my $f = i_run( $cmd, fail_ok => 1 );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error installing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error installing $pkg");
  }

  Rex::Logger::debug("$pkg successfully installed.");

  return 1;
}

sub remove {
  my ( $self, $pkg, $option ) = @_;

  Rex::Logger::debug("Removing $pkg");

  my $cmd = "pkgrm -n ";
  $cmd .= " -a " . $option->{"adminfile"} if ( $option->{"adminfile"} );

  my $f = i_run( $cmd . " $pkg", fail_ok => 1 );

  unless ( $? == 0 ) {
    Rex::Logger::info( "Error removing $pkg.", "warn" );
    Rex::Logger::debug($f);
    die("Error removing $pkg");
  }

  Rex::Logger::debug("$pkg successfully removed.");

  return 1;
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run "pkginfo -l";

  my ( @pkg, %current );

  for my $line (@lines) {
    if ( $line =~ m/^$/ ) {
      push( @pkg, {%current} );
      next;
    }

    if ( $line =~ m/PKGINST:\s+([^\s]+)/ ) {
      $current{"name"} = $1;
      next;
    }

    if ( $line =~ m/VERSION:\s+([^\s]+)/ ) {
      my ( $version, $rev ) = split( /,/, $1 );
      $current{"version"} = $version;
      $rev =~ s/^REV=// if ($rev);
      $current{"revision"} = $rev;
      next;
    }

    if ( $line =~ m/STATUS:\s+(.*?)$/ ) {
      $current{"status"} = ( $1 eq "completely installed" ? "installed" : $1 );
      next;
    }

  }

  return @pkg;
}

1;
