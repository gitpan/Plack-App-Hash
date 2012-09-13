use Test::More tests => 1;

BEGIN {
use_ok( 'Plack::App::Hash' )
or BAIL_OUT( 'testing pointless if the module won\'t even load' );
}
