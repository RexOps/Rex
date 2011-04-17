#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

package Rex::Commands::DB;

use strict;
use warnings;

use DBI;
use Rex::Logger;
use Data::Dumper;

use vars qw(@EXPORT $dbh);

@EXPORT = qw(db);


sub db {

   my ($type, $data) = @_;

   unless($data->{"from"}) {
      Rex::Logger::info("No table to select from defined (use from => '...')");
      return;
   }

   if($type eq "select") {
      my $sql = sprintf("SELECT %s FROM %s WHERE %s", $data->{"fields"} || "*", $data->{"from"}, $data->{"where"} || "");
      Rex::Logger::debug("sql: $sql");

      my $sth = $dbh->prepare($sql);
      $sth->execute;

      my @return;

      while(my $row = $sth->fetchrow_hashref) {
         push @return, $row;
      }
      $sth->finish;

      return @return;
   }
   else {
      Rex::Logger::info("DB $type not supported.");
   }

}


sub import {

   my ($class, $opt) = @_;

   $dbh = DBI->connect($opt->{"dsn"}, $opt->{"user"}, $opt->{"password"} // "");  

   my ($ns_register_to, $file, $line) = caller;   

   no strict 'refs';
   for my $func_name (@EXPORT) {
      *{"${ns_register_to}::$func_name"} = \&$func_name;
   }
   use strict;

}

1;
