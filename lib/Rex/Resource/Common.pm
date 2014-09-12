#
# (c) Jan Gehring <jan.gehring@gmail.com>
# 
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:
   
package Rex::Resource::Common;
   
use strict;
use warnings;
   
require Exporter;
require Rex::Config;
use base qw(Exporter);
use vars qw(@EXPORT);
    
@EXPORT = qw(emit resource resource_name changed);

sub changed { return "changed"; }
   
sub emit {
  my ($type) = @_;
  if(! $Rex::Resource::INSIDE_RES) {
    die "emit() only allowed inside resource.";
  }

  if($type eq changed) {
    current_resource()->changed(1);
  }
}

=item resource($name, $function)

=cut
sub resource {
  my ($name, $function) = @_;
  my $name_save = $name;

  if ( $name_save !~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    Rex::Logger::info(
      "Please use only the following characters for resource names:", "warn" );
    Rex::Logger::info( "  A-Z, a-z, 0-9 and _",                      "warn" );
    Rex::Logger::info( "Also the resource should start with A-Z or a-z", "warn" );
    die "Wrong resource name syntax.";
  }

  my ( $class, $file, @tmp ) = caller;
  my $res = Rex::Resource->new(type => "${class}::$name", name => $name, cb => $function);

  if (!$class->can($name)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    no strict 'refs';
    Rex::Logger::debug("Registering resource: ${class}::$name_save");

    my $code = $_[-2];
    *{"${class}::$name_save"} = sub {
      $res->call(@_);
    };
    use strict;
  }
  elsif ( ( $class ne "main" && $class ne "Rex::CLI" )
    && !$class->can($name_save)
    && $name_save =~ m/^[a-zA-Z_][a-zA-Z0-9_]+$/ )
  {
    # if not in main namespace, register the task as a sub
    no strict 'refs';
    Rex::Logger::debug(
      "Registering resource (not main namespace): ${class}::$name_save");
    my $code = $_[-2];
    *{"${class}::$name_save"} = sub {
      $res->call(@_);
    };

    use strict;
  }
}

sub resource_name {
  Rex::Config->set(resource_name => current_resource()->{res_name});
  return current_resource()->{res_name};
}

sub resource_ensure {
  my ($option) = @_;
  $option->{current_resource()->{res_ensure}}->();
}

sub current_resource {
  return $Rex::Resource::CURRENT_RES[-1];
}
   
1;
