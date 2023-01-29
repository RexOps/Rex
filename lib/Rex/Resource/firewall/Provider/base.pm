#
# (c) Jan Gehring <jan.gehring@gmail.com>
#

package Rex::Resource::firewall::Provider::base;

use v5.12.5;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

use Data::Dumper;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub present {
  my ( $self, $rule_config ) = @_;
  die "Must be implemented by provider.";
}

sub absent {
  my ( $self, $rule_config ) = @_;
  die "Must be implemented by provider.";
}

sub enable {
  my ( $self, $rule_config ) = @_;
  Rex::Logger::debug("enable: Not implemented by provider.");
}

sub disable {
  my ( $self, $rule_config ) = @_;
  Rex::Logger::debug("disable: Not implemented by provider.");
}

sub logging {
  my ( $self, $rule_config ) = @_;
  Rex::Logger::debug("logging: Not implemented by provider.");
}

1;
