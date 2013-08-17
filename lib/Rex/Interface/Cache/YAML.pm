#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Interface::Cache::YAML;

use Moo;
require Rex::Commands;
require Rex::Commands::Fs;
require YAML;

extends 'Rex::Interface::Cache::Base';

sub save {
   my ($self) = @_;

   my $path = Rex::Commands::get("cache_path") || ".cache";

   if(exists $ENV{REX_CACHE_PATH}) {
      $path = $ENV{REX_CACHE_PATH};
   }

   if(! -d $path) {
      Rex::Commands::LOCAL(sub { mkdir $path });
   }

   open(my $fh, ">", "$path/" . Rex::Commands::connection->server . ".yml") or die($!);
   print $fh YAML::Dump($self->{__data__});
   close($fh);
}

sub load {
   my ($self) = @_;

   my $path = Rex::Commands::get("cache_path") || ".cache";

   if(exists $ENV{REX_CACHE_PATH}) {
      $path = $ENV{REX_CACHE_PATH};
   }

   my $file_name = "$path/" . Rex::Commands::connection->server . ".yml";

   if(! -f $file_name) {
      # no cache found
      return;
   }

   my $yaml = eval { local(@ARGV, $/) = ($file_name); <>; };

   $yaml .= "\n";

   $self->{__data__} = YAML::Load($yaml);
}

1;
