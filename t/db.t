
use strict;
use warnings;

use Cwd 'getcwd';
my $cwd = getcwd;

BEGIN {
  use Test::More tests => 41;
  use Data::Dumper;

  use_ok 'Rex';
  use_ok 'Rex::Commands::DB';
  use_ok 'Rex::Config';
}
my $dbh;
SKIP: {
  eval { require Test::mysqld; Test::mysqld->import; };
  skip "Test::mysqld not installed", 38 if $@;
  my $mysqld = Test::mysqld->new(
    my_cnf => {
      'skip-networking' => '', # no TCP socket
    }
    )
    or do {
    no warnings 'once';
    plan skip_all => $Test::mysqld::errstr;
    };

  $dbh = DBI->connect( $mysqld->dsn( dbname => 'test' ), );
  Rex::Commands::DB->import( { dsn => $mysqld->dsn( dbname => 'test' ) } );
  _test_select();
  _test_insert();
  _test_delete();
  _test_update();
  _test_batch();
  done_testing();
}

sub _test_select {
  _initalize_db();
  my @data =
    db( 'select' => { fields => '*', from => 'mytest', where => 'id=2' } );
  is( $data[0]->{mykey}, "second", "correct value for id 2" );
  @data =
    db( 'select' => { fields => '*', from => 'mytest', where => 'id=5' } );
  is( $data[0], undef, "no data" );

  diag Dumper \@data;
  _cleanup_db();
}

sub _test_insert {
  _initalize_db();
  ok( db( insert => 'mytest', { id => 5, mykey => 'fifth' } ) );
  my @data =
    db( 'select' => { fields => '*', from => 'mytest', where => 'id=5' } );
  is( $data[0]->{mykey}, "fifth", "inserted fifths value" );
  _cleanup_db();
}

sub _test_delete {
  _initalize_db();
  ok(
    db(
      delete => 'mytest',
      {
        where => 'id = 1'
      }
    ),
    "deleted"
  );
  my @data =
    db( 'select' => { fields => '*', from => 'mytest', where => 'id=1' } );
  is( $data[0], undef, "no data returned delete ok" );

  _cleanup_db();
}

sub _test_update {
  _initalize_db();
  ok(
    db(
      'update',
      'mytest' => {
        set => {
          mykey => 'new value'
        },
        where => "id=2"
      }
    ),
    "updated"
  );
  my @data =
    db( 'select' => { fields => '*', from => 'mytest', where => 'id=2' } );
  is( $data[0]->{mykey}, "new value", "correct updated value for id 2" );

  _cleanup_db();
}

sub _test_batch {
TODO: {
    _initalize_db();
    _cleanup_db();
  }
}

sub _cleanup_db {
  ok( $dbh->do('DROP TABLE mytest'), "table mytest deleted" );
}

sub _initalize_db {

  ok( $dbh->do('CREATE TABLE mytest (id INT  primary key, mykey varchar(64))'),
    "table mytest created" );
  ok( $dbh->do('INSERT INTO mytest VALUES(1, "first")') );
  ok( $dbh->do('INSERT INTO mytest VALUES(2, "second")') );
  ok( $dbh->do('INSERT INTO mytest VALUES(3, "third")') );
  ok( $dbh->do('INSERT INTO mytest VALUES(4, "fourth")') );

}
