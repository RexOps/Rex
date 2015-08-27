#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Shared::Var::Common;

use strict;
use warnings;

require Exporter;
use base qw/Exporter/;
our @EXPORT_OK = qw/__lock __store __retrieve/;

# VERSION

use Fcntl qw(:DEFAULT :flock);
use Storable;

our $FILE      = "vars.db.$$";
our $LOCK_FILE = "vars.db.lock.$$";
our $PID       = $$;

sub __lock {
  sysopen( my $dblock, $LOCK_FILE, O_RDONLY | O_CREAT ) or die($!);
  flock( $dblock, LOCK_EX ) or die($!);

  my $ret = $_[0]->();

  close($dblock);

  return $ret;
}

sub __store {
  my $ref = shift;
  store( $ref, $FILE );
}

sub __retrieve {
  return {} unless -f $FILE;
  return retrieve($FILE);

}

sub END {
    # $PID gets set when Rex starts.  This value remains the same after the
    # process forks.  So $PID is always the pid of the master process.  $$
    # however is always the pid of the current process.  This checks if we are
    # in the master process or not and only removes the $FILE and $LOCK_FILE if
    # we are in the master process.

    # return if we exiting a child process
    return unless $$ eq $Rex::Shared::Var::Common::PID;

    # we are exiting the master process
    unlink $FILE      if -f $FILE;
    unlink $LOCK_FILE if -f $LOCK_FILE;
}

1;
