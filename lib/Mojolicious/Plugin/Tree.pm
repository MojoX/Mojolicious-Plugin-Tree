package Mojolicious::Plugin::Tree;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw(dumper);
use Carp qw(croak);
use SQL::Abstract::More;

our $VERSION = '0.01';

has 'sql'  => sub { SQL::Abstract::More->new() };
has 'conf' => sub { shift->{'conf'} };
has 'pg'   => sub { shift->{'conf'}->{'pg'} };

sub register {
    my ($self, $app, $conf) = @_;

    $conf->{'columns'}->{'id'}          = 'id'          if(!defined $conf->{'columns'}->{'id'});
    $conf->{'columns'}->{'date_create'} = 'date_create' if(!defined $conf->{'columns'}->{'date_create'});
    $conf->{'columns'}->{'date_update'} = 'date_update' if(!defined $conf->{'columns'}->{'date_update'});
    $conf->{'columns'}->{'parent_id'}   = 'parent_id'   if(!defined $conf->{'columns'}->{'parent_id'});
    $conf->{'columns'}->{'path'}        = 'path'        if(!defined $conf->{'columns'}->{'path'});
    $conf->{'columns'}->{'level'}       = 'level'       if(!defined $conf->{'columns'}->{'level'});

    $self->{'conf'} = $conf;

    my $namespace = $conf->{'namespace'};

    $app->helper("tree.$namespace.create"=>sub {
        my ($c, $parent_id) = @_;
        return $self->create($parent_id);
    });

    $app->helper("tree.$namespace.get"=>sub {
        my ($c, $id) = @_;
        return $self->get($id);
    });

    $app->helper("tree.$namespace.remove"=>sub {
        my ($c, $id) = @_;
        return $self->remove($id);
    });

    $app->helper("tree.$namespace.move"=>sub {
        my ($c, $id,$target_id) = @_;
        return $self->move($id,$target_id);
    });

    return;
}

sub create {
    my ($self, $parent_id) = @_;

    my $columns = $self->{'conf'}->{'columns'};

	my $parent_path = undef;
    if(defined $parent_id){
        if(my $get = $self->get($parent_id)){
            $parent_path = $get->{$columns->{'path'}};
        }
        else{
    		croak qq/invalid parent_id:$parent_id/;
        }
    }

    my ($sql, @bind) = $self->sql->insert(
        -into      => $self->{'conf'}->{'table'},
        -values    => {$columns->{'date_create'} => \['DEFAULT'], $columns->{'date_update'}=>\['DEFAULT']},
        -returning => $columns->{'id'},
    );

    my $id = $self->pg->db->query($sql,@bind)->hash->{$columns->{'id'}};

    my $path = $self->path($self->compress_int($id));
	$path = $parent_path.$path if(defined $parent_path);

    my $level = $self->level($path);

    ($sql, @bind) = $self->sql->update(
        -table => $self->{'conf'}->{'table'},
        -set   => {
            $columns->{'path'}=>$path,
            $columns->{'level'}=>$level,
            $columns->{'parent_id'}=>$parent_id,
        },
        -where => {$columns->{'id'}=>$id},
    );
    $self->pg->db->query($sql,@bind);
    return $self->get($id);
}

sub get {
    my ($self, $id) = @_;

    my $columns = $self->{'conf'}->{'columns'};
    my ($sql, @bind) = $self->sql->select(
        -columns  => [$columns->{'id'}, $columns->{'date_create'}, $columns->{'date_update'}, $columns->{'parent_id'}, $columns->{'path'}, $columns->{'level'}],
        -from     => $self->{'conf'}->{'table'},
        -where    => {$columns->{'id'}=>$id},
    );
    my $result = $self->pg->db->query($sql,@bind);
    croak qq/invalid id:$id/ if($result->rows == 0);

    $result = $result->hash;

    my @parents = split(/([0-9a-z]{6})/x,$result->{$columns->{'path'}});
    @parents = grep{$_} @parents;
    @parents = map { $self->decompress_int($_) } @parents;
    @parents = grep { $result->{$columns->{'id'}} != $_ } @parents;

    $result->{'parents'} = \@parents;

    # Children
    ($sql, @bind) = $self->sql->select(
        -columns  => [$columns->{'id'}, $columns->{'date_create'}, $columns->{'date_update'}, $columns->{'parent_id'}, $columns->{'path'}, $columns->{'level'}],
        -from     => $self->{'conf'}->{'table'},
        -where    => {
            $columns->{'path'}=>{-like => $result->{$columns->{'path'}}.'%'},
            $columns->{'id'}=>{'!=', $result->{$columns->{'id'}}},
            $columns->{'level'}=>$result->{$columns->{'level'}}+1,
        },
    );
    my $children = $self->pg->db->query($sql,@bind);

    my @children = ();
    while (my $next = $children->hash) {
        push(@children, $next->{$columns->{'id'}});
    }
    $result->{'children'} = \@children;
    return $result;
}

sub remove {
    my ($self,$id) = @_;

    my $columns = $self->{'conf'}->{'columns'};

	my $path = undef;
	my $get = $self->get($id);
	if(defined $get){
		$path = $get->{$columns->{'path'}};
	}
	else{
		croak "invalid id:$id";
	}

    my ($sql, @bind) = $self->sql->delete (
        -from     => $self->{'conf'}->{'table'},
        -where    => {$columns->{'path'}=>{-like => $path.'%'}},
    );
    $self->pg->db->query($sql,@bind);
    return;
}

sub move {
	my ($self,$id,$target_id) = @_;
    my $columns = $self->{'conf'}->{'columns'};

	my $get_id = $self->get($id);
	croak "invalid id:$id" if(!defined $id);

	my $get_target_id = $self->get($target_id);
	croak "invalid id:$get_target_id" if(!defined $get_target_id);

	croak "Impossible to transfer to itself or children" if($id eq $target_id);

	my $path        = $get_id->{'path'};
	my $path_target = $get_target_id->{'path'};
	croak "Impossible to transfer to itself or children" if($path =~ m/^$path_target/);

}

sub path {
    my ($self,$id) = @_;
    my $length_id = length($id);
    if($length_id < 6){
        my $zero = '0' x (6 - $length_id);
            $id = $zero.$id;
    }
    return $id;
}

sub level {
    my ($self,$path) = @_;
    my @counter = ($path =~ m/([0-9a-z]{6})/gx);
    return scalar @counter;
}

sub compress_int {
    my ($self,$int) = @_;
    croak qq/error max integer/ if($int >= 2176782335);

	my $value       = 0;
	my @symbol_list = (0..9,'a'..'z');
	my %symbol_map  = map { $_ => $value++ } @symbol_list;
	my $symbol_list = \@symbol_list;
	my $map         = \%symbol_map;
	my $base        = scalar @symbol_list;

	my $result;
	while ($int) {
		my $result_tmp = $symbol_list->[$int % $base];
        if(defined $result){
            $result = $result_tmp.$result
        }
        else{
            $result = $result_tmp
        }
		$int = int ($int / $base);
	}

    return $result;
}

sub decompress_int {
    my ($self,$string) = @_;

	my $value       = 0;
	my @symbol_list = (0..9,'a'..'z');
	my %symbol_map  = map { $_ => $value++ } @symbol_list;
	my $symbol_list = \@symbol_list;
	my $map         = \%symbol_map;
	my $base        = scalar @symbol_list;

	my $result = 0;
	my $power = 0;
	while (length $string) {
		my $char = chop $string;
		$result += $map->{$char} * ($base ** $power);
		$power++;
	}
	return $result;
}

1;

