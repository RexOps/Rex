#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cron::FreeBSD;

use strict;
use warnings;

# VERSION

use Rex::Cron::Base;
use base qw(Rex::Cron::Base);

use Rex::Helper::Run;
use Rex::Helper::Path;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = $proto->SUPER::new(@_);

  bless( $self, $proto );

  return $self;
}

sub read_user_cron {
  my ( $self, $user ) = @_;
  $user = undef if $user eq $self->_whoami;

  my $tmp_file = get_tmp_file;

  my $command = '( crontab -l';
  $command .= " -u $user" if defined $user;
  $command .= " >$tmp_file ) >& /dev/null ; cat $tmp_file ; rm $tmp_file";

  my @lines = i_run $command;
  $self->parse_cron(@lines);
}

1;
