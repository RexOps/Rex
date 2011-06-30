#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::DB - Simple Database Access

=head1 DESCRIPTION

This module gives you simple access to a database. Currently only I<select> is supported.

=head1 SYNOPSIS

 use Rex::Commands::DB {
                           dsn      => "DBI:mysql:database=test;host=dbhost",
                           user     => "username",
                           password => "password",
                       };
 
 task "list", sub {
    my @data = db select => {
                  fields => "*",
                  from   => "table",
                  where  => "enabled=1",
               };
 };


=head1 EXPORTED FUNCTIONS

=over 4

=cut

package Rex::Commands::DB;

use strict;
use warnings;

use DBI;
use Rex::Logger;
use Data::Dumper;

use vars qw(@EXPORT $dbh);

@EXPORT = qw(db);

=item db

Do a database action. Currently only I<select> is supported.

 my @data = db select => {
               fields => "*",
               from   => "table",
               where  => "host='myhost'",
            };

=cut

sub db {

   my ($type, $table, $data) = @_;
   if(ref($table)) {
      my %d = %{$table};
      delete $d{"from"};
      $data = \%d;

      $table = $table->{"from"};
   }

   unless($table) {
      Rex::Logger::info("No table defined...')");
      return;
   }

   if($type eq "select") {
      my $sql = sprintf("SELECT %s FROM %s WHERE %s", $data->{"fields"} || "*", $table, $data->{"where"} || "1=1");
      Rex::Logger::debug("sql: $sql");

      my $sth = $dbh->prepare($sql);
      $sth->execute or die($sth->errstr);

      my @return;

      while(my $row = $sth->fetchrow_hashref) {
         push @return, $row;
      }
      $sth->finish;

      return @return;
   }
   elsif($type eq "insert") {
      my $sql = "INSERT INTO %s (%s) VALUES(%s)";

      my @values;
      for my $key (keys %{$data}) {
         push(@values, "?");
      }

      $sql = sprintf($sql, $table, join(",", keys %{$data}), join(",", @values));
      Rex::Logger::debug("sql: $sql");

      my $sth = $dbh->prepare($sql);
      my $i=1;
      for my $key (keys %{$data}) {
         Rex::Logger::debug("sql: binding: " . $data->{$key});
         $sth->bind_param($i, $data->{$key}) or die($sth->errstr);
         $i++;
      }

      $sth->execute or die($sth->errstr);
   }
   else {
      Rex::Logger::info("DB $type not supported.");
   }

}

=back

=cut

sub quote_sql {
   my ($s) = @_;

   $s =~ s/'/\\'/g;
   $s =~ s/"/\\"/g;
   $s =~ s/\\/\\\\/g;
   $s =~ s/\0/\\0/g;

   return $s;
}

sub import {

   my ($class, $opt) = @_;

   $dbh = DBI->connect($opt->{"dsn"}, $opt->{"user"}, $opt->{"password"} || "");  

   my ($ns_register_to, $file, $line) = caller;   

   no strict 'refs';
   for my $func_name (@EXPORT) {
      *{"${ns_register_to}::$func_name"} = \&$func_name;
   }
   use strict;

}

1;



