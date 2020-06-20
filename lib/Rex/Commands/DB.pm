#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::DB - Simple Database Access

=head1 DESCRIPTION

This module gives you simple access to a database. Currently I<select>, I<delete>, I<insert> and I<update> is supported.

Version <= 1.0: All these functions will not be reported.

=head1 SYNOPSIS

 use Rex::Commands::DB {
                  dsn    => "DBI:mysql:database=test;host=dbhost",
                  user    => "username",
                  password => "password",
                };
 
 task "list", sub {
   my @data = db select => {
            fields => "*",
            from  => "table",
            where  => "enabled=1",
          };
 
  db insert => "table", {
           field1 => "value1",
            field2 => "value2",
            field3 => 5,
          };
 
  db update => "table", {
              set => {
                field1 => "newvalue",
                field2 => "newvalue2",
              },
              where => "id=5",
           };
 
  db delete => "table", {
            where => "id < 5",
          };
 
 };


=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::DB;

use strict;
use warnings;

# VERSION

BEGIN {
  use Rex::Require;
  DBI->require;
}

use Rex::Logger;
use Data::Dumper;
use Symbol;

use vars qw(@EXPORT $dbh);

@EXPORT = qw(db);

=head2 db

Do a database action.

 my @data = db select => {
          fields => "*",
          from  => "table",
          where  => "host='myhost'",
        };
 
 db insert => "table", {
          field1 => "value1",
          field2 => "value2",
          field3 => 5,
        };
 
 db update => "table", {
            set => {
              field1 => "newvalue",
              field2 => "newvalue2",
            },
            where => "id=5",
         };
 
 db delete => "table", {
          where => "id < 5",
        };

=cut

sub db {

  my ( $type, $table, $data ) = @_;
  if ( ref($table) ) {
    my %d = %{$table};
    delete $d{"from"};
    $data = \%d;

    $table = $table->{"from"};
  }

  unless ($table) {
    Rex::Logger::info("No table defined...')");
    return;
  }

  if ( $type eq "select" ) {
    my $sql = sprintf(
      "SELECT %s FROM %s WHERE %s",
      $data->{"fields"} || "*",
      $table, $data->{"where"} || "1=1"
    );
    if ( defined $data->{"order"} ) {
      $sql .= " ORDER BY " . $data->{"order"};
    }
    Rex::Logger::debug("sql: $sql");

    my $sth = $dbh->prepare($sql);
    $sth->execute or die( $sth->errstr );

    my @return;

    while ( my $row = $sth->fetchrow_hashref ) {
      push @return, $row;
    }
    $sth->finish;

    return @return;
  }
  elsif ( $type eq "insert" ) {
    my $sql = "INSERT INTO %s (%s) VALUES(%s)";

    my @values;
    for my $key ( keys %{$data} ) {
      push( @values, "?" );
    }

    $sql =
      sprintf( $sql, $table, join( ",", keys %{$data} ), join( ",", @values ) );
    Rex::Logger::debug("sql: $sql");

    my $sth = $dbh->prepare($sql);
    my $i   = 1;
    for my $key ( keys %{$data} ) {
      $data->{$key} ||= '';
      Rex::Logger::debug( "sql: binding: " . $data->{$key} );
      $sth->bind_param( $i, $data->{$key} ) or die( $sth->errstr );
      $i++;
    }

    $sth->execute or die( $sth->errstr );
  }
  elsif ( $type eq "update" ) {
    my $sql = "UPDATE %s SET %s WHERE %s";

    my @values;
    for my $key ( keys %{ $data->{"set"} } ) {
      push( @values, "$key = ?" );
    }

    $sql = sprintf( $sql, $table, join( ",", @values ), $data->{"where"} );
    Rex::Logger::debug("sql: $sql");

    my $sth = $dbh->prepare($sql);
    my $i   = 1;
    for my $key ( keys %{ $data->{"set"} } ) {
      Rex::Logger::debug( "sql: binding: " . $data->{"set"}->{$key} );
      $sth->bind_param( $i, $data->{"set"}->{$key} ) or die( $sth->errstr );
      $i++;
    }

    $sth->execute or die( $sth->errstr );
  }
  elsif ( $type eq "delete" ) {
    my $sql = sprintf( "DELETE FROM %s WHERE %s", $table, $data->{"where"} );
    my $sth = $dbh->prepare($sql);
    $sth->execute or die( $sth->errstr );
  }
  else {
    Rex::Logger::info("DB: action $type not supported.");
  }

}

sub import {

  my ( $class, $opt ) = @_;

  if ($opt) {
    $dbh = DBI->connect(
      $opt->{"dsn"}, $opt->{"user"},
      $opt->{"password"} || "", $opt->{"attr"}
    );
    $dbh->{mysql_auto_reconnect} = 1;
  }

  my ( $ns_register_to, $file, $line ) = caller;

  for my $func_name (@EXPORT) {
    my $ref_to_function = qualify_to_ref( $func_name, $ns_register_to );
    *{$ref_to_function} = \&$func_name;
  }

}

1;
