use Mojo::Base -strict;
use Test::More;
use Mojolicious::Lite;
use Test::Mojo;
use Mojo::Util qw(dumper);
use Mojo::Pg;
use Try::Tiny;
use FindBin;
use lib "$FindBin::Bin/../lib/";

my $pg = Mojo::Pg->new('postgresql://postgres@localhost/tree');

$pg->db->query('DROP TABLE IF EXISTS tree;');
$pg->db->query('
    CREATE TABLE tree (
        id              SERIAL      PRIMARY KEY,
        date_create     TIMESTAMP   with time zone NOT NULL DEFAULT current_timestamp,
        date_update     TIMESTAMP   with time zone NOT NULL DEFAULT current_timestamp,
        parent_id       INTEGER     NULL,
        path            TEXT        NULL,
        level           INTEGER     NULL
    );
');


plugin Tree => {
    pg => $pg,
    namespace=>'mynamespace',
    table=>'tree',
    columns=>{
        id=>'id',
        date_create=>'date_create',
        date_update=>'date_update',
        parent_id=>'parent_id',
        path=>'path',
        level=>'level'
    }
};

my $result = app->tree->mynamespace->create();

note('create');
ok(scalar @{$result->{'children'}} == 0, 'children');
like($result->{'date_create'}, qr/^[0-9]{4}\-[0-9]{2}\-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}/, 'date_create');
like($result->{'date_update'}, qr/^[0-9]{4}\-[0-9]{2}\-[0-9]{2}\s[0-9]{2}:[0-9]{2}:[0-9]{2}/, 'date_update');
ok($result->{'id'} == 1, 'id');
ok($result->{'level'} == 1, 'level');
ok(!defined $result->{'parent_id'} == 1, 'parent_id');
ok(scalar @{$result->{'parents'}} == 0, 'parents');
ok($result->{'path'} eq '000001', 'path');

note('sub create');
$result = app->tree->mynamespace->create($result->{'id'});
ok($result->{'path'} eq '000001000002', 'path');
ok(scalar @{$result->{'parents'}} == 1, 'parents');
ok($result->{'level'} == 2, 'level');

note('get');
$result = app->tree->mynamespace->get(1);
ok(scalar @{$result->{'children'}} == 1, 'children');

app->tree->mynamespace->remove(1);

try {
    app->tree->mynamespace->get(1);
}
catch {
    like($_, qr/^invalid id:1/, 'check invalid id:1');
};

my $id1 = app->tree->mynamespace->create();
my $id2 = app->tree->mynamespace->create();
app->tree->mynamespace->move($id1->{'id'},$id2->{'id'});

done_testing();



