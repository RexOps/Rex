#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::File::Stat;

use strict;
use warnings;

# VERSION

require Rex::Helper::File::Stat::Unix;
require Rex::Helper::File::Stat::Win32;

sub S_ISDIR {
  shift;
  _fcntl()->S_ISDIR(@_);
}

sub S_ISREG {
  shift;
  _fcntl()->S_ISREG(@_);
}

sub S_ISLNK {
  shift;
  _fcntl()->S_ISLNK(@_);
}

sub S_ISBLK {
  shift;
  _fcntl()->S_ISBLK(@_);
}

sub S_ISCHR {
  shift;
  _fcntl()->S_ISCHR(@_);
}

sub S_ISFIFO {
  shift;
  _fcntl()->S_ISFIFO(@_);
}

sub S_ISSOCK {
  shift;
  _fcntl()->S_ISSOCK(@_);
}

sub S_IMODE {
  shift;
  _fcntl()->S_IMODE(@_);
}

sub _fcntl {
  if ( $^O =~ m/^MSWin/ ) {
    return "Rex::Helper::File::Stat::Win32";
  }
  else {
    return "Rex::Helper::File::Stat::Unix";
  }
}

1;
