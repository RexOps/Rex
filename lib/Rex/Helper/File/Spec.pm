#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Helper::File::Spec;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require File::Spec::Unix;
require File::Spec::Win32;

sub catfile {
  shift @_;
  _spec()->catfile(@_);
}

sub catdir {
  shift @_;
  _spec()->catdir(@_);
}

sub join {
  shift @_;
  _spec()->join(@_);
}

sub splitdir {
  shift @_;
  _spec()->splitdir(@_);
}

sub tmpdir {
  shift @_;
  _spec()->tmpdir(@_);
}

sub rootdir {
  shift @_;
  _spec()->rootdir(@_);
}

sub _spec {
  if ( Rex::is_ssh() ) {
    return "File::Spec::Unix";
  }
  else {
    if ( $^O =~ m/^MSWin/ ) {
      return "File::Spec::Win32";
    }
    else {
      return "File::Spec::Unix";
    }
  }
}

1;
