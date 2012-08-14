package MR::OnlineConf::Updater::ConfFiles;

use Mouse;
use File::Spec;
use JSON;
use POSIX qw/strftime/;

has dir => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has log => (
    is  => 'ro',
    isa => 'Log::Dispatch',
    required => 1,
);

has _data => (
    is  => 'ro',
    isa => 'HashRef',
    default => sub { {} },
);

sub update {
    my ($self, $root) = @_;
    my @failed;
    my $map = $root->get('/onlineconf/module');
    return unless $map;
    foreach my $module (keys %{$map->children}) {
        local $self->{seen_node} = {};
        my $child = $map->child($module);
        $child = $child->real_node();
        next if !$child;
        my $data = $self->_walk_tree($child);
        eval { $self->_dump_module($module, $data); 1 }
            or do {
                $self->log->error($@);
                push @failed, $module;
            };
    }
    die sprintf "Failed to write modules: %s\n", join ', ', @failed if @failed;
    return;
}

sub _walk_tree {
    my ($self, $node) = @_;
    my %data;
    local $self->{seen_node}->{$node->id} = 1;
    foreach my $name (keys %{$node->children}) {
        my $child = $node->child($name);
        next if $self->{seen_node}->{$child->id};
        $child = $child->real_node();
        next if !$child || $self->{seen_node}->{$child->id};
        if (!$child->is_null) {
            my $value = $child->value;
            if (ref $value) {
                $data{"$name:JSON"} = eval { JSON::to_json($value) };
            } else {
                $value = '' unless defined $value;
                $value =~ s/\n/\\n/g;
                $value =~ s/\r/\\r/g;
                $data{$name} = $value;
            }
        }
        my $child_data = $self->_walk_tree($child);
        $data{"$name.$_"} = $child_data->{$_} foreach keys %$child_data;
    }
    return \%data;
}

sub _dump_module {
    my ($self, $module, $data) = @_;
    my $s = "# This file is autogenerated by $0 at ".strftime("%Y/%d/%m %H:%M:%S" , localtime)."\n";
    $s .= "#! Name $module\n";
    $s .= "#! Version ".time()."\n\n";
    foreach my $k (sort keys %$data){
        my $v = $data->{$k};
        if ($module eq 'TREE') {
            $k =~ s/\./\//g;
            $k = "/$k";
        }
        $s .= "$k $v\n";
    }
    $s .= "#EOF";
    return unless $self->_module_modified($module, $s);
    my $filename = File::Spec->catfile($self->dir, "$module.conf");
    open my $f, '>:utf8', "${filename}_tmp" or die "Can't open file ${filename}_tmp: $!\n";
    print $f $s;
    close $f;
    rename "${filename}_tmp", $filename or die "Can't rename ${filename}_tmp to $filename: $!";
    return;
}

sub _module_modified {
    my ($self, $module, $content) = @_;
    my $current;
    my $filename = File::Spec->catfile($self->dir, "$module.conf");
    open my $f, '<:utf8', $filename or return 1;
    while (<$f>) {
        $current .= $_ unless /^#/;
    }
    close $f;
    $content =~ s/^#.*\n?//gm;
    return $content ne $current;
}

no Mouse;
__PACKAGE__->meta->make_immutable();

1;
