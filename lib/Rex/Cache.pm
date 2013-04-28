#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Cache;
   
use strict;
use warnings;

use Rex::Logger;
require Rex::Commands::Run;

our $USE = 0;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self;
}

sub call_sub {
   my ($self, $package, $func, @params) = @_;

   my $cache_key = "${package}_${func}_" . join("-", @params);

   if(defined $self->get($cache_key) && $USE) {
      return $self->get($cache_key);
   }

   my $ret;
   eval {
      my $package_file = $package;
      $package_file =~ s/::/\//g;
      require $package_file . ".pm";

      no strict 'refs';
      $ret = &{"${package}::${func}"}(@params);
      use strict;
      $self->set($cache_key, $ret);
   };

   if($@) {
      die($@);
   }

   return $ret;
}

sub call_method {
   my ($self, $package, $method, @params) = @_;

   my $cache_key = "${package}_${method}_" . join("-", @params);

   if(defined $self->get($cache_key) && $USE) {
      return $self->get($cache_key);
   }

   my $ret;
   eval {
      my $package_file = $package;
      $package_file =~ s/::/\//g;
      require $package_file . ".pm";

      $ret = $package->$method(@params);
      $self->set($cache_key, $ret);
   };

   if($@) {
      die($@);
   }

   return $ret;
  
}

sub run {
   my $self = shift;

   my $cache_key = "run_cmd_" . join("-", @_);

   if(defined $self->get($cache_key) && $USE) {
      return $self->get($cache_key);
   }

   my $ret = Rex::Commands::Run::run(@_);
   $self->set($cache_key, $ret);

   return $ret;
}

sub can_run {
   my $self = shift;

   my $cache_key = "can_run_cmd_" . join("-", @_);

   if(defined $self->get($cache_key) && $USE) {
      return $self->get($cache_key);
   }

   my $ret = Rex::Commands::Run::can_run(@_);
   $self->set($cache_key, $ret);

   return $ret;
}

sub set {
   my ($self, $key, $val) = @_;
   $self->{__data__}->{$key} = $val;
}

sub get {
   my ($self, $key) = @_;
   return $self->{__data__}->{$key};
}

sub reset {
   my ($self) = @_;
   $self->{__data__} = {};
}

1;
