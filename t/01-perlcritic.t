use Mojo::Base -strict;
use FindBin;
use lib "$FindBin::Bin/../lib/";
use Test::More;
use Test::Perl::Critic (-profile => "$FindBin::Bin/../.perlcriticrc");
use Test::Mojo;
use Mojo::Util qw(dumper);
$ENV{'MOJO_TEST'} = 1;

all_critic_ok("$FindBin::Bin/../lib/");


