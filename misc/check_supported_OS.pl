if ( $^O eq 'MSWin32' ) {
  my ( undef, $major ) = Win32::GetOSVersion();

  if ( $major < 6 ) {
    die 'OS unsupported';
  }
}
