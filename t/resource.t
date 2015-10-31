use Test::More tests => 11;
use Rex -base;
use Rex::Resource;
use Rex::Resource::Common;

$::QUIET = 1;

resource(
  "testres",
  sub {
    my $name = resource_name;
    my $file = param_lookup "file", "/etc/passwd";

    is( $name, "foo",         "testres name is foo" );
    is( $file, "/etc/passwd", "testres got default file param" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/passwd", "got default parameter in template" );

    emit changed;
  }
);

resource(
  "testres2",
  sub {
    my $name = resource_name;
    my $file = param_lookup "file", "/etc/passwd";

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
  sub {
    my $name = resource_name;
    my $file = param_lookup "file", "/etc/passwd";

    is( $name, "baz",      "testres3 name is baz" );
    is( $file, "/etc/foo", "testres3 got custom param" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/foo", "got custom parameter in template (nested resource)" );
  }
);

task(
  "test1",
  sub {
    my $file = param_lookup "file", "/etc/groups";

    testres("foo");
    testres2( "bar", file => "/etc/shadow" );

    my $x = template( \'<%= $file %>' );
    is( $x, "/etc/securetty", "task got custom parameter in template" );
  }
);

test1( { file => "/etc/securetty" } );

done_testing();

