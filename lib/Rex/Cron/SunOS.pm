#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Cron::SunOS;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Rex::Cron::Base;
use base qw(Rex::Cron::Base);

use Rex::Helper::Run;
use Rex::Commands::Fs;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub read_user_cron {
  my ( $self, $user ) = @_;
  my @lines = i_run "crontab -l $user";
  $self->parse_cron(@lines);
}

sub activate_user_cron {
  my ( $self, $file, $user ) = @_;
  i_run "crontab $file";
  unlink $file;
}

1;
