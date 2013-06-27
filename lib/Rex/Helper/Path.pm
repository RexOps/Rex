#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:
   
package Rex::Helper::Path;

use strict;
use warnings;

use File::Basename qw(dirname);
require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);
use Cwd 'realpath';

require Rex::Commands;
require Rex::Config;
require Rex;

@EXPORT = qw(get_file_path get_tmp_file);

#
# CALL: get_file_path("foo.txt", caller());
# RETURNS: module file
#
sub get_file_path {
   my ($file_name, $caller_package, $caller_file) = @_;

   if(! $caller_package) {
      ($caller_package, $caller_file) = caller();
   }

   # check if a file in $BASE overwrites the module file
   # first get the absoltue path to the rexfile

   my @path_parts = split(/\//, realpath($::rexfile));
   pop @path_parts;

   my $real_path = join('/', @path_parts);

   if(-f $file_name) {
      return $file_name;
   }

   if(-f $real_path . '/' . $file_name) {
      return $real_path . '/' . $file_name;
   }

   my $module_path = Rex::get_module_path($caller_package);
   if($module_path) {
      $file_name = "$module_path/$file_name";
   }
   else {
      $file_name = dirname($caller_file) . "/" . $file_name;
   }

   return $file_name;
}

sub get_tmp_file {
   my $rnd_file;

   if(Rex::is_ssh()) {
      $rnd_file = "/tmp/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp";
   }
   elsif($^O =~ m/^MSWin/) {
      $rnd_file = $ENV{TMP} . "/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp"
   }
   else {
      $rnd_file = "/tmp/" . Rex::Commands::get_random(12, 'a' .. 'z') . ".tmp";
   }

   return $rnd_file;
}

1;
