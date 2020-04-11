#
# (c) Jan Gehring <jan.gehring@gmail.com>
#
# vim: set ts=2 sw=2 tw=0:
# vim: set expandtab:

package Rex::Cron::Base;

use strict;
use warnings;

# VERSION

use Rex::Logger;
use Rex::Commands;
use Rex::Commands::File;
use Rex::Commands::Fs;
use Rex::Helper::Run;
use Data::Dumper;
use Rex::Helper::Path;

sub new {
  my $that  = shift;
  my $proto = ref($that) || $that;
  my $self  = {@_};

  bless( $self, $proto );

  return $self;
}

sub list {
  my ($self) = @_;
  return @{ $self->{cron} };
}

sub list_jobs {
  my ($self) = @_;
  my @jobs = @{ $self->{cron} };
  my @ret =
    map { { line => $_->{line}, %{ $_->{cron} } } }
    grep { $_->{type} eq "job" } @jobs;
}

sub list_envs {
  my ($self) = @_;
  my @jobs   = @{ $self->{cron} };
  my @ret    = grep { $_->{type} eq "env" } @jobs;
}

sub add {
  my ( $self, %config ) = @_;

  %config = $self->_create_defaults(%config);

  my $new_cron = sprintf(
    "%s %s %s %s %s %s",
    $config{"minute"}, $config{"hour"},        $config{"day_of_month"},
    $config{"month"},  $config{"day_of_week"}, $config{"command"},
  );

  my $dupe = grep { $_->{line} eq $new_cron } @{ $self->{cron} };
  if ($dupe) {
    Rex::Logger::debug("Job \"$new_cron\" already installed, skipping.");
    return 0;
  }

  push(
    @{ $self->{cron} },
    {
      type => "job",
      line => $new_cron,
      cron => \%config,
    }
  );

  return 1;
}

sub add_env {
  my ( $self, $name, $value ) = @_;

  my $env_index = 0;
  my $exists    = 0;
  for my $env ( $self->list_envs ) {
    if ( $env->{name} eq "$name" ) {
      if ( $env->{value} ne "\"$value\"" ) {
        Rex::Logger::debug("Environment variable changed : $name");
        $self->delete_env($env_index);
      }
      else {
        Rex::Logger::debug(
          "Environment variable already exists with same value: $name=$value");
        $exists = 1;
      }
    }

    $env_index++;
  }

  if ( $exists == 0 ) {
    unshift(
      @{ $self->{cron} },
      {
        type  => "env",
        line  => "$name=\"$value\"",
        name  => $name,
        value => $value,
      }
    );
  }
}

sub delete_job {
  my ( $self, $num ) = @_;
  my @jobs = $self->list_jobs;

  my $i = 0;
  my $to_delete;
  for my $j ( @{ $self->{cron} } ) {
    if ( $j->{line} eq $jobs[$num]->{line} ) {
      $to_delete = $i;
      last;
    }

    $i++;
  }

  unless ( defined $to_delete ) {
    die("Cron Entry $num not found.");
  }

  $self->delete($to_delete);
}

sub delete_env {
  my ( $self, $num ) = @_;

  my @jobs = $self->list_envs;

  my $i = 0;
  my $to_delete;
  for my $j ( @{ $self->{cron} } ) {
    if ( $j->{line} eq $jobs[$num]->{line} ) {
      $to_delete = $i;
      last;
    }

    $i++;
  }

  unless ( defined $to_delete ) {
    die("Cron Entry $num not found.");
  }

  $self->delete($to_delete);
}

sub delete {
  my ( $self, $num ) = @_;
  splice( @{ $self->{cron} }, $num, 1 );
}

# returns a filename where the new cron is written to
# after that the cronfile must be activated
sub write_cron {
  my ($self) = @_;

  my $rnd_file = get_tmp_file;

  my @lines = map { $_->{line} } @{ $self->{cron} };

  my $fh = file_write $rnd_file;
  $fh->write( join( "\n", @lines ) . "\n" );
  $fh->close;

  return $rnd_file;
}

sub activate_user_cron {
  my ( $self, $file, $user ) = @_;
  $user = undef if $user eq &_whoami;

  my $command = 'crontab';
  $command .= " -u $user" if defined $user;

  i_run "$command $file";
  unlink $file;
}

sub read_user_cron {
  my ( $self, $user ) = @_;
  $user = undef if $user eq &_whoami;

  my $command = 'crontab -l';
  $command .= " -u $user" if defined $user;
  $command .= ' 2> /dev/null';

  my @lines = i_run $command, fail_ok => 1;
  $self->parse_cron(@lines);
}

sub parse_cron {
  my ( $self, @lines ) = @_;

  chomp @lines;

  my @cron;

  for my $line (@lines) {

    # comment
    if ( $line =~ m/^#/ ) {
      push(
        @cron,
        {
          type => "comment",
          line => $line,
        }
      );
    }

    # empty line
    elsif ( $line =~ m/^\s*$/ ) {
      push(
        @cron,
        {
          type => "empty",
          line => $line,
        }
      );
    }

    # job
    elsif ( $line =~ m/^(@|\*|[0-9])/ ) {
      my ( $min, $hour, $day, $month, $dow, $cmd ) = split( /\s+/, $line, 6 );
      push(
        @cron,
        {
          type => "job",
          line => $line,
          cron => {
            minute       => $min,
            hour         => $hour,
            day_of_month => $day,
            month        => $month,
            day_of_week  => $dow,
            command      => $cmd,
          },
        }
      );
    }

    elsif ( $line =~ m/=/ ) {
      my ( $name, $value ) = split( /=/, $line, 2 );
      $name  =~ s/^\s+//;
      $name  =~ s/\s+$//;
      $value =~ s/^\s+//;
      $value =~ s/\s+$//;

      push(
        @cron,
        {
          type  => "env",
          line  => $line,
          name  => $name,
          value => $value,
        }
      );
    }

    else {
      Rex::Logger::debug("Error parsing cron line: $line");
      next;
    }

  }

  $self->{cron} = \@cron;
  return @cron;
}

sub _create_defaults {
  my ( $self, %config ) = @_;

  $config{"minute"}       = "*" unless defined $config{minute};
  $config{"hour"}         = "*" unless defined $config{hour};
  $config{"day_of_month"} = "*" unless defined $config{day_of_month};
  $config{"month"}        = "*" unless defined $config{month};
  $config{"day_of_week"}  = "*" unless defined $config{day_of_week};
  $config{"command"} ||= "false";

  return %config;
}

sub _whoami {
  return i_run q(perl -e 'print scalar getpwuid($<)');
}

1;
