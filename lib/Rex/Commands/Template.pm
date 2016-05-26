package Rex::Commands::Template;

use strict;
use warnings;

# VERSION

require Rex::Exporter;

use Data::Dumper;
use Rex::Config;
use Rex::FS::File;
use Rex::Commands::Upload;
use Rex::Commands::MD5;
use Rex::File::Parser::Data;
use Rex::Helper::System;
use Rex::Helper::Path;
use Rex::Hook;
use Carp;

use Rex::Interface::Exec;
use Rex::Interface::File;
use Rex::Interface::Fs;
require Rex::CMDB;

use File::Basename qw(dirname basename);

use vars qw(@EXPORT);
use base qw(Rex::Exporter);

@EXPORT = qw/template/;

=head2 template($file, @params)

Parse a template and return the content.

 my $content = template("/files/templates/vhosts.tpl",
              name => "test.lan",
              webmaster => 'webmaster@test.lan');

The file name specified is subject to "path_map" processing as documented
under the file() function to resolve to a physical file name.

In addition to the "path_map" processing, if the B<-E> command line switch
is used to specify an environment name, existence of a file ending with
'.<env>' is checked and has precedence over the file without one, if it
exists. E.g. if rex is started as:

 $ rex -E prod task1

then in task1 defined as:

 task "task1", sub {

    say template("files/etc/ntpd.conf");

 };

will print the content of 'files/etc/ntpd.conf.prod' if it exists.

Note: the appended environment mechanism is always applied, after
the 'path_map' mechanism, if that is configured.


=cut

sub template {
  my ( $file, @params ) = @_;
  my $param;

  if ( ref $params[0] eq "HASH" ) {
    $param = $params[0];
  }
  else {
    $param = {@params};
  }

  if ( !exists $param->{server} ) {
    $param->{server} = Rex::Commands::connection()->server;
  }

  my $content;
  if ( ref $file && ref $file eq 'SCALAR' ) {
    $content = ${$file};
  }
  else {
    $file = resolv_path($file);

    unless ( $file =~ m/^\// || $file =~ m/^\@/ ) {

      # path is relative and no template
      Rex::Logger::debug("Relativ path $file");

      $file = Rex::Helper::Path::get_file_path( $file, caller() );

      Rex::Logger::debug("New filename: $file");
    }

    # if there is a file called filename.environment then use this file
    # ex:
    # $content = template("files/hosts.tpl");
    #
    # rex -E live ...
    # will first look if files/hosts.tpl.live is available, if not it will
    # use files/hosts.tpl
    if ( -f "$file." . Rex::Config->get_environment ) {
      $file = "$file." . Rex::Config->get_environment;
    }

    if ( -f $file ) {
      $content = eval { local ( @ARGV, $/ ) = ($file); <>; };
    }
    elsif ( $file =~ m/^\@/ ) {
      my @caller = caller(0);

      my $file_path = Rex::get_module_path( $caller[0] );

      if ( !-f $file_path ) {
        my ($mod_name) = ( $caller[0] =~ m/^.*::(.*?)$/ );
        if ( $mod_name && -f "$file_path/$mod_name.pm" ) {
          $file_path = "$file_path/$mod_name.pm";
        }
        elsif ( -f "$file_path/__module__.pm" ) {
          $file_path = "$file_path/__module__.pm";
        }
        elsif ( -f "$file_path/Module.pm" ) {
          $file_path = "$file_path/Module.pm";
        }
        elsif ( -f $caller[1] ) {
          $file_path = $caller[1];
        }
        elsif ( $caller[1] =~ m|^/loader/[^/]+/__Rexfile__.pm$| ) {
          $file_path = $INC{"__Rexfile__.pm"};
        }
      }

      my $file_content = eval { local ( @ARGV, $/ ) = ($file_path); <>; };
      my ($data) = ( $file_content =~ m/.*__DATA__(.*)/ms );
      my $fp = Rex::File::Parser::Data->new( data => [ split( /\n/, $data ) ] );
      my $snippet_to_read = substr( $file, 1 );
      $content = $fp->read($snippet_to_read);
    }
    else {
      die("$file not found");
    }
  }

  my %template_vars;
  if ( !exists $param->{__no_sys_info__} ) {
    %template_vars = _get_std_template_vars($param);
  }
  else {
    delete $param->{__no_sys_info__};
    %template_vars = %{$param};
  }

  # configuration variables
  my $config_values = Rex::Config->get_all;
  for my $key ( keys %{$config_values} ) {
    if ( !exists $template_vars{$key} ) {
      $template_vars{$key} = $config_values->{$key};
    }
  }

  if ( Rex::CMDB::cmdb_active() && Rex::Config->get_register_cmdb_template ) {
    my $data = Rex::CMDB::cmdb();
    for my $key ( keys %{ $data->{value} } ) {
      if ( !exists $template_vars{$key} ) {
        $template_vars{$key} = $data->{value}->{$key};
      }
    }
  }

  return Rex::Config->get_template_function()->( $content, \%template_vars );
}

sub _get_std_template_vars {
  my ($param) = @_;

  my %merge1 = %{ $param || {} };
  my %merge2;

  if ( Rex::get_cache()->valid("system_information_info") ) {
    %merge2 = %{ Rex::get_cache()->get("system_information_info") };
  }
  else {
    %merge2 = Rex::Helper::System::info();
    Rex::get_cache()->set( "system_information_info", \%merge2 );
  }

  my %template_vars = ( %merge1, %merge2 );

  return %template_vars;
}

1;
