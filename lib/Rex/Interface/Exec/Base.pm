#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::Base;

use strict;
use warnings;

# VERSION

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub exec { die("Must be implemented by Interface Class"); }

sub _continuous_read {
  my ( $self, $line, $option ) = @_;
  my $cb = $option->{continuous_read} || undef;

  if ( defined($cb) && ref($cb) eq 'CODE' ) {
    &$cb($line);
  }
}

sub _end_if_matched {
  my ( $self, $line, $option ) = @_;
  my $regex = $option->{end_if_matched} || undef;

  if ( defined($regex) && ref($regex) eq 'Regexp' && $line =~ m/$regex/ ) {
    return 1;
  }
  return;
}

sub execute_line_based_operation {
  my ( $self, $line, $option ) = @_;

  $self->_continuous_read( $line, $option );
  return $self->_end_if_matched( $line, $option );
}

sub can_run {
  my ( $self, @cmds ) = @_;

  if ( !Rex::is_ssh() && $^O =~ m/^MSWin/ ) {
    return 1;
  }

  for my $cmd (@cmds) {
    my @ret = Rex::Helper::Run::i_run "which $cmd";
    next if ( $? != 0 );

    if ( grep { /^no.*in/ } @ret ) {
      next;
    }
    else {
      return $ret[0];
    }
  }

  return 0;
}

1;
