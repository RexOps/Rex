#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Pkg::Mageia;

use strict;
use warnings;

use Rex::Commands::Run;
use Rex::Helper::Run;
use Rex::Pkg::Base;
use base qw(Rex::Pkg::Base);

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  $self->{commands} = {
    install           => 'urpmi --auto --quiet %s',
    install_version   => 'urpmi --auto --quiet %s',
    update_system     => 'urpmi --auto --quiet --auto-update',
    remove            => 'urpme --auto %s',
    update_package_db => 'urpmi.update -a',
  };

  return $self;
}

sub get_installed {
  my ($self) = @_;

  my @lines = i_run
    'rpm -qa --nosignature --nodigest --qf "%{NAME} %|EPOCH?{%{EPOCH}}:{0}| %{VERSION} %{RELEASE} %{ARCH}\n"';

  my @pkg;

  for my $line (@lines) {
    if ( $line =~ m/^([^\s]+)\s([^\s]+)\s([^\s]+)\s([^\s]+)\s(.*)$/ ) {
      push(
        @pkg,
        {
          name    => $1,
          epoch   => $2,
          version => $3,
          release => $4,
          arch    => $5,
        }
      );
    }
  }

  return @pkg;
}

sub add_repository {
  my ( $self, %data ) = @_;
  my $name = $data{"name"};

  i_run "urpmi.addmedia $name " . $data{"url"};
  if ( $? != 0 ) {
    die("Error adding repository $name");
  }
}

sub rm_repository {
  my ( $self, $name ) = @_;
  i_run "urpmi.removemedia $name";
  if ( $? != 0 ) {
    die("Error removing repository $name");
  }
}

1;
