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
use File::Spec;

# $PARENT_PID gets set when Rex starts.  This value remains the same after the
# process forks.  So $PARENT_PID is always the pid of the parent process.  $$
# however is always the pid of the current process.
our $PARENT_PID = $$;
our $FILE = File::Spec->catfile( File::Spec->tmpdir(), "vars.db.$PARENT_PID" );
our $LOCK_FILE =
  File::Spec->catfile( File::Spec->tmpdir(), "vars.db.lock.$PARENT_PID" );

sub __lock {
  sysopen( my $dblock, $LOCK_FILE, O_RDONLY | O_CREAT ) or die($!);
  flock( $dblock, LOCK_EX )                             or die($!);

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

  # return if we exiting a child process
  return unless $$ eq $PARENT_PID;

  # we are exiting the master process
  unlink $FILE      if -f $FILE;
  unlink $LOCK_FILE if -f $LOCK_FILE;
}

1;
