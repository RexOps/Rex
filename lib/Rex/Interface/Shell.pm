#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Shell;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Logger;

my %SHELL_PROVIDER = (
  ash   => "Rex::Interface::Shell::Ash",
  bash  => "Rex::Interface::Shell::Bash",
  csh   => "Rex::Interface::Shell::Csh",
  idrac => "Rex::Interface::Shell::Idrac",
  ksh   => "Rex::Interface::Shell::Ksh",
  sh    => "Rex::Interface::Shell::Sh",
  tcsh  => "Rex::Interface::Shell::Tcsh",
  zsh   => "Rex::Interface::Shell::Zsh",
);

sub register_shell_provider {
  my ( $class, $shell_name, $shell_class ) = @_;
  $SHELL_PROVIDER{"\L$shell_name"} = $shell_class;
  return 1;
}

sub get_shell_provider {
  return %SHELL_PROVIDER;
}

sub create {
  my ( $class, $shell ) = @_;

  $shell =~ s/[\r\n]//gms; # sometimes there are some wired things...

  my $klass = "Rex::Interface::Shell::\u$shell";
  eval "use $klass";
  if ($@) {
    Rex::Logger::info(
      "Can't load wanted shell: '$shell' ('$klass'). Using default shell.",
      "warn" );
    Rex::Logger::info(
      "If you want to help the development of Rex please report this issue in our Github issue tracker.",
      "warn"
    );
    $klass = "Rex::Interface::Shell::Default";
    eval "use $klass";
  }

  return $klass->new;
}

1;
