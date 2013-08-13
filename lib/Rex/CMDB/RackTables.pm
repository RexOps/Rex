package Rex::CMDB::RackTables;

use strict;
use warnings;

use Rex::Commands -no => [qw/get/];
use Rex::Logger;

use RackMan;
use RackMan::Config;

use Data::Dumper;

sub new {
   my $that = shift;
   my $proto = ref($that) || $that;
   my $self = { @_ };

   bless($self, $proto);

   return $self
}

sub get {
   my ($self, $item, $server) = @_;

   my $env = environment;
   
   my @files = ("./racktables-$env.ini", "./racktables.ini"); 

   for my $file (@files) {
      Rex::Logger::debug("CMDB - Opening $file");
      if(-f "$file") {
         my $config  = RackMan::Config->new(-file => $file);
         my $rackman = RackMan->new({ config => $config});
         my $rackobj = $rackman->device($server);

         return $rackobj->ports->[0]->{l2address_text} if($item eq 'mac');
      }
   }

   Rex::Logger::debug("CMDB - no item ($item) found");

   return undef;
}

1;
