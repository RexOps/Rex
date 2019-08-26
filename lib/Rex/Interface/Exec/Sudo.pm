#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Interface::Exec::Sudo;

use strict;
use warnings;

# VERSION

use Rex::Config;
use Rex::Interface::Exec::Local;
use Rex::Interface::Exec::SSH;
use Rex::Helper::Encode;
use Rex::Interface::File::Local;
use Rex::Interface::File::SSH;

use Rex::Commands;
use Rex::Helper::Path;

use base 'Rex::Interface::Exec::Base';

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub exec {
  my ( $self, $cmd, $path, $option ) = @_;

  if ( exists $option->{cwd} ) {
    $cmd = "cd " . $option->{cwd} . " && $cmd";
  }

  if ( exists $option->{path} ) {
    $path = $option->{path};
  }

  my ( $exec, $file, $shell );
  if ( my $ssh = Rex::is_ssh() ) {
    if ( ref $ssh eq "Net::OpenSSH" ) {
      $exec = Rex::Interface::Exec->create("OpenSSH");
      $file = Rex::Interface::File->create("OpenSSH");
    }
    else {
      $exec = Rex::Interface::Exec->create("SSH");
      $file = Rex::Interface::File->create("SSH");
    }
  }
  else {
    $exec = Rex::Interface::Exec->create("Local");
    $file = Rex::Interface::File->create("Local");
  }
  $shell = Rex::Interface::Shell->create("Sh"); # we're using sh for sudo

######## envs setzen. aber erst nachdem wir wissen ob wir sh forcen duerfen
  # if(exists $option->{env}) {
  #   $shell->set_environment($option->{env});
  # }

  my $sudo_password = (
    defined task() ? task->get_sudo_password : Rex::Config->get_sudo_password );
  my $enc_pw;
  my $random_file = "";

  Rex::Logger::debug("Sudo: Executing: $cmd");

  if ($sudo_password) {
    my $random_string = get_random( length($sudo_password), 'a' .. 'z' );
    my $crypt         = $sudo_password ^ $random_string;

    $random_file = get_tmp_file;

    $file->open( '>', $random_file );
    $file->write(<<EOF);
#!/usr/bin/perl
unlink \$0;

for (0..255) {
  \$escapes{chr(\$_)} = sprintf("%%%02X", \$_);
}

my \$txt = \$ARGV[0];

\$txt=~ s/%([0-9A-Fa-f]{2})/chr(hex(\$1))/eg;

my \$rnd = '$random_string';
print \$txt ^ \$rnd;
print "\\n"

EOF

    $file->close;

    $enc_pw = Rex::Helper::Encode::url_encode($crypt);
  }
  else {
    $enc_pw = "";
  }

  #my $sudo_options     = Rex::get_current_connection()->{sudo_options};
  my $sudo_options =
    Rex::get_current_connection_object()->get_current_sudo_options;
  my $sudo_options_str = "";
  if ( exists $sudo_options->{user} ) {
    $sudo_options_str .= " -u " . $sudo_options->{user};
  }

  if ( Rex::Config->get_sudo_without_locales() ) {
    Rex::Logger::debug(
      "Using sudo without locales. If the locale is NOT C or en_US it will break many things!"
    );
    $option->{no_locales} = 1;
  }

  my $sudo_command = "sudo $sudo_options_str -p '' -S";

  if ( Rex::Config->get_sudo_without_sh() ) {
    Rex::Logger::debug(
      "Using sudo without sh will break things like file editing.");

    # $option->{no_sh} = 1;
    $shell->set_inner_shell(0);
    $shell->set_sudo_env(1);

    if ( exists $option->{env} ) {
      $shell->set_environment( $option->{env} );
    }

    if ($enc_pw) {

    # $option->{format_cmd} =
    #   "perl $random_file '$enc_pw' | sudo $sudo_options_str -p '' -S {{CMD}}";
      $sudo_command = "perl $random_file '$enc_pw' 2>/dev/null | $sudo_command";
    }

    # else {
    #   $option->{format_cmd} = "sudo $sudo_options_str -p '' -S {{CMD}}";
    # }
  }
  else {

    $shell->set_locale("C");
    $shell->path($path);

    if ( Rex::Config->get_source_global_profile ) {
      $shell->source_global_profile(1);
    }

    if ( Rex::Config->get_source_profile ) {
      $shell->source_profile(1);
    }

    if ( exists $option->{env} ) {
      $shell->set_environment( $option->{env} );
    }

    # escape some special shell things
    # $option->{preprocess_command} = sub {
    #   my ($_cmd) = @_;
    #   $_cmd =~ s/\\/\\\\/gms;
    #   $_cmd =~ s/"/\\"/gms;
    #   $_cmd =~ s/\$/\\\$/gms;
    # };

    $shell->set_inner_shell(1);

    # $cmd =~ s/\\/\\\\/gms;
    # $cmd =~ s/"/\\"/gms;
    # $cmd =~ s/\$/\\\$/gms;

# Calling sudo with sh(1) in this case we don't need to respect current user shell, pass _force_sh flag to ssh layer
# $option->{_force_sh} = 1;

    if ($enc_pw) {
      $sudo_command = "perl $random_file '$enc_pw' 2>/dev/null | $sudo_command";

# $option->{format_cmd} =
#   "perl $random_file '$enc_pw' | sudo $sudo_options_str -p '' -S sh -c \"{{CMD}}\"";
    }

    # else {
    #   $option->{format_cmd} =
    #     "sudo $sudo_options_str -p '' -S sh -c \"{{CMD}}\"";
    # }
  }

  $option->{prepend_command} = $sudo_command;

  my $real_exec = $shell->exec( $cmd, $option );
  Rex::Logger::debug("sudo: exec: $real_exec");

  return $exec->direct_exec( $real_exec, $option );
}

sub _exec {
  my ( $self, $cmd, $path, $option ) = @_;

  my ( $exec, $file, $shell );
  if ( my $ssh = Rex::is_ssh() ) {
    if ( ref $ssh eq "Net::OpenSSH" ) {
      $exec = Rex::Interface::Exec->create("OpenSSH");
    }
    else {
      $exec = Rex::Interface::Exec->create("SSH");
    }
  }
  else {
    $exec = Rex::Interface::Exec->create("Local");
  }

  return $exec->_exec( $cmd, $option );
}

1;
