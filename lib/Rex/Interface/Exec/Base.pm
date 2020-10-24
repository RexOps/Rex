#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::Base;

use 5.010001;
use strict;
use warnings;
use Carp;
use Rex::Helper::Run;

our $VERSION = '9999.99.99_99'; # VERSION

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
  my ( $self, $commands_to_check, $check_with_command ) = @_;

  $check_with_command ||= "which";

  my $exec  = Rex::Interface::Exec->create;
  my $cache = Rex::get_cache();

  for my $command ( @{$commands_to_check} ) {

    my $cache_key_name = $cache->gen_key_name("can_run.cmd/$command");
    if ( $cache->valid($cache_key_name) ) {
      return $cache->get($cache_key_name);
    }

    my @output = Rex::Helper::Run::i_run "$check_with_command $command",
      fail_ok => 1;

    next if ( $? != 0 );
    next if ( grep { /^no $command in/ } @output ); # for solaris

    $cache->set( $cache_key_name, $output[0] );

    return $output[0];
  }

  return undef;
}

sub direct_exec {
  my ( $self, $exec, $option ) = @_;

  Rex::Commands::profiler()->start("direct_exec: $exec");

  my $class_name = ref $self;

  Rex::Logger::debug("$class_name/executing: $exec");
  my ( $out, $err ) = $self->_exec( $exec, $option );

  Rex::Commands::profiler()->end("direct_exec: $exec");

  Rex::Logger::debug($out) if ($out);
  if ($err) {
    Rex::Logger::debug("========= ERR ============");
    Rex::Logger::debug($err);
    Rex::Logger::debug("========= ERR ============");
  }

  if (wantarray) { return ( $out, $err ); }

  return $out;
}

sub _exec {
  my ($self) = @_;
  my $class_name = ref $self;
  die("_exec method must be overwritten by class ($class_name).");
}

sub shell {
  my ($self) = @_;

  Rex::Logger::debug("Detecting shell...");

  my $cache = Rex::get_cache();
  if ( $cache->valid("shell") ) {
    Rex::Logger::debug( "Found shell in cache: " . $cache->get("shell") );
    return Rex::Interface::Shell->create( $cache->get("shell") );
  }

  my %shells = Rex::Interface::Shell->get_shell_provider;
  for my $shell ( keys %shells ) {
    Rex::Logger::debug( "Searching for shell: " . $shell );
    $shells{$shell}->require;
    if ( $shells{$shell}->detect($self) ) {
      Rex::Logger::debug( "Found shell and using: " . $shell );
      $cache->set( "shell", $shell );
      return Rex::Interface::Shell->create($shell);
    }
  }

  return Rex::Interface::Shell->create("sh");
}

1;
