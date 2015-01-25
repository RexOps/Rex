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

=over 4

=cut

package Rex::Augeas;

use strict;
use warnings;

# VERSION

require Exporter;

use base qw(Exporter);
use vars qw(@EXPORT);

use Rex::Logger;
use Rex::Commands;
use Rex::Commands::Run;
use Rex::Commands::Fs;
use Rex::Commands::File;

use Config::Augeas;
use IO::String;

@EXPORT = qw(augeas);

=item augeas($action, @options)

It returns 1 on success and 0 on failure.

Actions:

=over 4

=cut

sub augeas {
  my ( $action, @options ) = @_;
  my $ret;

  Rex::Logger::debug("Creating Config::Augeas Object");
  my $aug = Config::Augeas->new;

  my $is_ssh = Rex::is_ssh();

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

    $ret = 1; # Assume success
    for my $key ( keys %{$config_option} ) {
      my $aug_key = $key;
      Rex::Logger::debug( "modifying $aug_key -> " . $config_option->{$key} );

      my $_r;
      if ($is_ssh) {
        my $result =
            run 'echo "set '
          . $aug_key . ' '
          . $config_option->{$key}
          . '" | augtool -s';
        $changed = 1 if $result =~ /Saved/;
        if ( $? == 0 ) {
          $_r = 1;
        }
        else {
          $_r  = 0;
          $ret = 0; # Return zero on any failures
        }
      }
      else {
        $_r = $aug->set( $aug_key, $config_option->{$key} );

        # Final return value obtained during final save
      }
      Rex::Logger::debug("Augeas set status: $_r");
    }

    unless ($is_ssh) {
      $ret = $aug->save;
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
    if ( $options[-2] eq 'on_change' && ref $options[-1] eq 'CODE' ) {
      $on_change = pop @options;
      pop @options;
    }

    $ret = 1; # Assume success
    for my $key (@options) {
      my $aug_key = $key;
      Rex::Logger::debug("deleting $aug_key");

      my $_r;
      if ($is_ssh) {
        my $result = run "echo 'rm $aug_key' | augtool -s";
        $changed = 1 if $result =~ /Saved/;
        if ( $? == 0 ) {
          $_r = 1;
        }
        else {
          $_r  = 0;
          $ret = 0; # Return zero on any failures
        }
      }
      else {
        $_r = $aug->remove($aug_key);

        # Final return value obtained during final save
      }
      Rex::Logger::debug("Augeas delete status: $_r");
    }

    unless ($is_ssh) {
      $ret = $aug->save;
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
    if ( $options[-2] eq 'on_change' && ref $options[-1] eq 'CODE' ) {
      $on_change = pop @options;
      pop @options;
    }

    if ($is_ssh) {
      my $position = ( exists $opts->{"before"} ? "before" : "after" );
      unless ( exists $opts->{$position} ) {
        Rex::Logger::info(
          "Error inserting key. You have to specify before or after.");
        return 0;
      }

      my $aug_commands = "ins $label $position " . $opts->{$position} . "\n";

      delete $opts->{$position};

      for ( my $i = 0 ; $i < @options ; $i += 2 ) {
        my $key = $options[$i];
        my $val = $options[ $i + 1 ];
        next if ( $key eq "after" or $key eq "before" or $key eq "label" );

        my $_key = "$file/$label/$key";
        Rex::Logger::debug("Setting $_key => $val");

        $aug_commands .= "set $_key $val\n";
      }

      $aug_commands .= "save\n";

      my $tmp_file = "/tmp/" . get_random( 12, 'a' .. 'z', 0 .. 9 ) . '.tmp';
      my $fh = file_write $tmp_file;
      $fh->write($aug_commands);
      $fh->close;

      my $result = run "cat $tmp_file | augtool";
      $changed = 1 if $result =~ /Saved/;

      $ret = 0;
      if ( $? == 0 ) {
        $ret = 1;
      }

      unlink "$tmp_file";
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

      $ret = $aug->save();
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

    if ($is_ssh) {
      my @list = run "augtool print $aug_key";
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
    my $val = $options[0] || "";

    if ($is_ssh) {
      my @paths = grep { s/\s=[^=]+$// } run "echo 'match $aug_key' | augtool";

      if ($val) {
        for my $k (@paths) {
          my @ret = grep { s/^[^=]+=\s// } run "echo 'get $k' | augtool";

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

    if ($is_ssh) {
      my @lines = grep { s/^[^=]+=\s//; } run "echo 'get $file' | augtool";
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

1;

