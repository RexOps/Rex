die 'OS unsupported' if ( $^O eq 'MSWin32' && scalar((Win32::GetOSVersion())[1]) < 6 );
