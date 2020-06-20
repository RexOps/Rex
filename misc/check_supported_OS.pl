if ( $^O eq 'MSWin32' ) {
  my ( undef, $major, $minor ) = Win32::GetOSVersion();

  if ( $major < 6 ) {
    die 'OS unsupported';
  }
  elsif ( $major == 6 && $minor < 2 ) {
    die 'OS unsupported';
  }
}
