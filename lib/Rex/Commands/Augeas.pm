#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=3 sw=3 tw=0:
# vim: set expandtab:

=head1 NAME

Rex::Commands::Augeas - An augeas module for (R)?ex

=head1 DESCRIPTION

This is a simple module to manipulate configuration files with the help of augeas.

=head1 SYNOPSIS

 my $k = augeas exists => "/files/etc/hosts/*/ipaddr", "127.0.0.1";
    
 augeas insert => "/files/etc/hosts",
           label => "01",
           after => "/7",
           ipaddr => "192.168.2.23",
           canonical => "test";
   
 augeas dump => "/files/etc/hosts";

 augeas modify =>
    "/files/etc/ssh/sshd_config/PermitRootLogin" => "without-password",
    on_change => sub {
       service ssh => "restart";
    };

=head1 EXPORTED FUNCTIONS

=cut

package Rex::Commands::Augeas;

use 5.010001;
use strict;
use warnings;

our $VERSION = '9999.99.99_99'; # VERSION

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;
use Rex::Helper::Path;
use Rex::Helper::Run;
use IO::String;

my $has_config_augeas = 0;

BEGIN {
  use Rex::Require;
  if ( Config::Augeas->is_loadable ) {
    Config::Augeas->use;
    $has_config_augeas = 1;
  }
}

@EXPORT = qw(augeas);

=head2 augeas($action, @options)

It returns 1 on success and 0 on failure.

Actions:

=over 4

=cut

sub augeas {
  my ( $action, @options ) = @_;
  my $ret;

  my $is_ssh = Rex::is_ssh();
  my $aug; # Augeas object (non-SSH only)
  if ( !$is_ssh && $has_config_augeas ) {
    Rex::Logger::debug("Creating Config::Augeas Object");
    $aug = Config::Augeas->new;
  }

  my $on_change; # Any code to run on change
  my $changed;   # Whether any changes have taken place

=item modify

This modifies the keys given in @options in $file.

 augeas modify =>
           "/files/etc/hosts/7/ipaddr"    => "127.0.0.2",
           "/files/etc/hosts/7/canonical" => "test01",
           on_change                      => sub { say "I changed!" };

=cut

  if ( $action eq "modify" ) {
    my $config_option = {@options};

    # Code to run on a change being made
    $on_change = delete $config_option->{on_change}
      if ref $config_option->{on_change} eq 'CODE';

    if ( $is_ssh || !$has_config_augeas ) {
      my @commands;
      for my $key ( keys %{$config_option} ) {
        Rex::Logger::debug( "modifying $key -> " . $config_option->{$key} );
        push @commands, qq(set $key "$config_option->{$key}"\n);
      }
      my $result = _run_augtool(@commands);
      $ret     = $result->{return};
      $changed = $result->{changed};
    }
    else {
      for my $key ( keys %{$config_option} ) {
        Rex::Logger::debug( "modifying $key -> " . $config_option->{$key} );
        $aug->set( $key, $config_option->{$key} );
      }
      $ret = $aug->save;
      Rex::Logger::debug("Augeas set status: $ret");
      $changed = 1 if $ret && $aug->get('/augeas/events/saved'); # Any files changed?
    }
  }

=item remove

Remove an entry.

 augeas remove    => "/files/etc/hosts/2",
        on_change => sub { say "I changed!" };

=cut

  elsif ( $action eq "remove" ) {

    # Code to run on a change being made
    if ( $options[-2]
      && $options[-2] eq 'on_change'
      && ref $options[-1] eq 'CODE' )
    {
      $on_change = pop @options;
      pop @options;
    }

    my @commands;
    for my $aug_key (@options) {
      Rex::Logger::debug("deleting $aug_key");

      if ( $is_ssh || !$has_config_augeas ) {
        push @commands, "rm $aug_key\n";
      }
      else {
        my $_r = $aug->remove($aug_key);
        Rex::Logger::debug("Augeas delete status: $_r");
      }
    }

    if ( $is_ssh || !$has_config_augeas ) {
      my $result = _run_augtool(@commands);
      $ret     = $result->{return};
      $changed = $result->{changed};
    }
    else {
      $ret     = $aug->save;
      $changed = 1 if $ret && $aug->get('/augeas/events/saved'); # Any files changed?
    }

  }

=item insert

Insert an item into the file. Here, the order of the options is important. If the order is wrong it won't save your changes.

 augeas insert => "/files/etc/hosts",
           label     => "01",
           after     => "/7",
           ipaddr    => "192.168.2.23",
           alias     => "test02",
           on_change => sub { say "I changed!" };

=cut

  elsif ( $action eq "insert" ) {
    my $file = shift @options;
    my $opts = {@options};

    my $label = $opts->{"label"};
    delete $opts->{"label"};

    # Code to run on a change being made
    if ( $options[-2]
      && $options[-2] eq 'on_change'
      && ref $options[-1] eq 'CODE' )
    {
      $on_change = pop @options;
      pop @options;
    }

    if ( $is_ssh || !$has_config_augeas ) {
      my $position = ( exists $opts->{"before"} ? "before" : "after" );
      unless ( exists $opts->{$position} ) {
        Rex::Logger::info(
          "Error inserting key. You have to specify before or after.");
        return 0;
      }

      my @commands = ("ins $label $position $file$opts->{$position}\n");
      delete $opts->{$position};

      for ( my $i = 0 ; $i < @options ; $i += 2 ) {
        my $key = $options[$i];
        my $val = $options[ $i + 1 ];
        next if ( $key eq "after" or $key eq "before" or $key eq "label" );

        my $_key = "$file/$label/$key";
        Rex::Logger::debug("Setting $_key => $val");

        push @commands, qq(set $_key "$val"\n);
      }
      my $result = _run_augtool(@commands);
      $ret     = $result->{return};
      $changed = $result->{changed};
    }
    else {
      if ( exists $opts->{"before"} ) {
        $aug->insert( $label, before => "$file" . $opts->{"before"} );
        delete $opts->{"before"};
      }
      elsif ( exists $opts->{"after"} ) {
        my $t = $aug->insert( $label, after => "$file" . $opts->{"after"} );
        delete $opts->{"after"};
      }
      else {
        Rex::Logger::info(
          "Error inserting key. You have to specify before or after.");
        return 0;
      }

      for ( my $i = 0 ; $i < @options ; $i += 2 ) {
        my $key = $options[$i];
        my $val = $options[ $i + 1 ];

        next if ( $key eq "after" or $key eq "before" or $key eq "label" );

        my $_key = "$file/$label/$key";
        Rex::Logger::debug("Setting $_key => $val");

        $aug->set( $_key, $val );
      }

      $ret     = $aug->save();
      $changed = 1 if $ret && $aug->get('/augeas/events/saved'); # Any files changed?
    }
  }

=item dump

Dump the contents of a file to STDOUT.

 augeas dump => "/files/etc/hosts";

=cut

  elsif ( $action eq "dump" ) {
    my $file    = shift @options;
    my $aug_key = $file;

    if ( $is_ssh || !$has_config_augeas ) {
      my @list = i_exec "augtool", "print", $aug_key;
      print join( "\n", @list ) . "\n";
    }
    else {
      $aug->print($aug_key);
    }
    $ret = 0;
  }

=item exists

Check if an item exists.

 my $exists = augeas exists => "/files/etc/hosts/*/ipaddr" => "127.0.0.1";
 if($exists) {
     say "127.0.0.1 exists!";
 }

=cut

  elsif ( $action eq "exists" ) {
    my $file = shift @options;

    my $aug_key = $file;
    my $val     = $options[0] || "";

    if ( $is_ssh || !$has_config_augeas ) {
      my @paths;
      my $result = _run_augtool("match $aug_key");
      for my $line ( split "\n", $result->{return} ) {
        $line =~ s/\s=[^=]+$// or next;
        push @paths, $line;
      }

      if ($val) {
        for my $k (@paths) {
          my @ret;
          my $result = _run_augtool("get $k");
          for my $line ( split "\n", $result->{return} ) {
            $line =~ s/^[^=]+=\s//;
            push @ret, $line;
          }

          if ( $ret[0] eq $val ) {
            return $k;
          }
        }
      }
      else {
        return @paths;
      }

      $ret = undef;
    }
    else {
      my @paths = $aug->match($aug_key);

      if ($val) {
        for my $k (@paths) {
          if ( $aug->get($k) eq $val ) {
            return $k;
          }
        }
      }
      else {
        return @paths;
      }

      $ret = undef;
    }
  }

=item get

Returns the value of the given item.

 my $val = augeas get => "/files/etc/hosts/1/ipaddr";

=cut

  elsif ( $action eq "get" ) {
    my $file = shift @options;

    if ( $is_ssh || !$has_config_augeas ) {
      my @lines;
      my $result = _run_augtool("get $file");
      for my $line ( split "\n", $result->{return} ) {
        $line =~ s/^[^=]+=\s//;
        push @lines, $line;
      }
      return $lines[0];
    }
    else {
      return $aug->get($file);
    }
  }

  else {
    Rex::Logger::info("Unknown augeas action.");
  }

  if ( $on_change && $changed ) {
    Rex::Logger::debug("Calling on_change hook of augeas");
    $on_change->();
  }

  Rex::Logger::debug("Augeas Returned: $ret") if $ret;

  return $ret;
}

=back

=cut

sub _run_augtool {
  my (@commands) = @_;

  die "augtool is not installed or not executable in the path"
    unless can_run "augtool";
  my $rnd_file = get_tmp_file;
  my $fh       = Rex::Interface::File->create;
  $fh->open( ">", $rnd_file );
  $fh->write($_) foreach (@commands);
  $fh->close;
  my ( $return, $error ) = i_run "augtool --file $rnd_file --autosave",
    sub { @_ }, fail_ok => 1;
  my $ret = $? == 0 ? 1 : 0;

  if ($ret) {
    Rex::Logger::debug("Augeas command return value: $ret");
    Rex::Logger::debug("Augeas result: $return");
  }
  else {
    Rex::Logger::info( "Augeas command failed: $error", 'warn' );
  }
  my $changed = "$return" =~ /Saved/ ? 1 : 0;
  unlink $rnd_file;

  {
    result  => $ret,
    return  => $return || $error,
    changed => $changed,
  };
}

1;

