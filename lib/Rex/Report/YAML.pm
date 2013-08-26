#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Report::YAML;

use strict;
use warnings;

use Data::Dumper;
use Rex::Report::Base;
require Rex::Commands;
use YAML;
use base qw(Rex::Report::Base);

our $REPORT_PATH = "./reports";

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = $proto->SUPER::new(@_);

   bless($self, $proto);

   $self->{__reports__} = [];

   return $self;
}

sub report {
   my ($self, $msg) = @_;
   push @{$self->{__reports__}}, $msg; 
}

sub write_report {
   my ($self) = @_;

   if(! -d $REPORT_PATH) {
      mkdir $REPORT_PATH or die($!);
   }

   my $server_name = Rex::Commands::connection->server;

   if(! -d $REPORT_PATH . "/" . $server_name) {
      mkdir "$REPORT_PATH/$server_name";
   }
   open(my $fh, ">", "$REPORT_PATH/$server_name/" . time() . ".yml") or die($!);
   print $fh Dump($self->{__reports__});
   close($fh);

   $self->{__reports__} = [];
}

1;
