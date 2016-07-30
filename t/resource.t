use Test::More tests => 11;
use Rex -base;
use Rex::Resource;
use Rex::Resource::Common;
use Rex::Output;

use Data::Dumper;

$::QUIET = 1;

resource(
  "testres",
  {
    params_list => [
      name => {
        isa     => 'Str',
        default => sub { shift }
      },
      file => { isa => 'Str', default => "/etc/passwd", },
    ],
  },
  sub {
    my ($c)  = @_;
    my $name = $c->param("name");
    my $file = $c->param("file");

    is( $name, "foo",         "testres name is foo" );
    is( $file, "/etc/passwd", "testres got default file param" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/passwd", "got default parameter in template" );

    emit changed;
  }
);

resource(
  "testres2",
  {
    params_list => [
      name => {
        isa     => 'Str',
        default => sub { shift }
      },
      file => { isa => 'Str', },
    ],
  },
  sub {
    my ($c)  = @_;
    my $name = $c->param("name");
    my $file = $c->param("file");

    is( $name, "bar",         "testres2 name is bar" );
    is( $file, "/etc/shadow", "testres2 got custom param" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/shadow", "got custom parameter in template" );

    testres3( "baz", file => "/etc/foo" );

    $x = template( \'after: <%= $file %>' );
    is(
      $x,
      "after: /etc/shadow",
      "got custom parameter in template after nested resource call"
    );
  }
);

resource(
  "testres3",
  {
    params_list => [
      name => {
        isa     => 'Str',
        default => sub { shift }
      },
      file => { isa => 'Str', },
    ],
  },
  sub {
    my ($c)  = @_;
    my $name = $c->param("name");
    my $file = $c->param("file");

    is( $name, "baz",      "testres3 name is baz" );
    is( $file, "/etc/foo", "testres3 got custom param" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/foo", "got custom parameter in template (nested resource)" );
  }
);

task(
  "test1",
  sub {
    my $c = shift;
    my $file = $c->param("file") || "/etc/securetty";

    testres("foo");
    testres2( "bar", file => "/etc/shadow" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/securetty", "task got custom parameter in template" );
  }
);

test1( file => "/etc/securetty" );

done_testing();

