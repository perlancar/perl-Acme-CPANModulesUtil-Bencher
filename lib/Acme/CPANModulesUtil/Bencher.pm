package Acme::CPANModulesUtil::Bencher;

use 5.010001;
use strict 'subs', 'vars';
use warnings;

# AUTHORITY
# DATE
# DIST
# VERSION

our %SPEC;

use Exporter qw(import);
our @EXPORT_OK = qw(gen_bencher_scenario);

$SPEC{gen_bencher_scenario} = {
    v => 1.1,
    summary => 'Generate/extract Bencher scenario from information in an Acme::CPANModules::* list',
    description => <<'_',

An <pm:Acme::CPANModules>::* module can contain benchmark information, for
example in <pm:Acme::CPANModules::TextTable>, each entry has the following
property:

      entries => [
          ...
          {
              module => 'Text::ANSITable',
              ...
              bench_code => sub {
                  my ($table) = @_;
                  my $t = Text::ANSITable->new(
                      use_utf8 => 0,
                      use_box_chars => 0,
                      use_color => 0,
                      columns => $table->[0],
                      border_style => 'Default::single_ascii',
                  );
                  $t->add_row($table->[$_]) for 1..@$table-1;
                  $t->draw;
              },

              # per-function participant
              functions => {
                  'func1' => {
                      bench_code_template => 'Text::ANSITable::func1([])',
                  },
                  ...
              },

The list also contains information about the benchmark datasets:

    bench_datasets => [
        {name=>'tiny (1x1)'    , argv => [_make_table( 1, 1)],},
        {name=>'small (3x5)'   , argv => [_make_table( 3, 5)],},
        {name=>'wide (30x5)'   , argv => [_make_table(30, 5)],},
        {name=>'long (3x300)'  , argv => [_make_table( 3, 300)],},
        {name=>'large (30x300)', argv => [_make_table(30, 300)],},
    ],

This routine extract those information and return a <pm:Bencher> scenario
structure.

_
    args => {
        cpanmodule => {
            summary => 'Name of Acme::CPANModules::* module, without the prefix',
            schema => 'perl::modname*',
            req => 1,
            pos => 0,
            'x.completion' => ['perl_modname' => {ns_prefix=>'Acme::CPANModules'}],
        },
    },
};
sub gen_bencher_scenario {
    my %args = @_;

    my $list;
    my $mod;

    if ($args{_list}) {
        $list = $args{_list};
    } else {
        $mod = $args{cpanmodule} or return [400, "Please specify cpanmodule"];
        $mod = "Acme::CPANModules::$mod" unless $mod =~ /\AAcme::CPANModules::/;
        (my $mod_pm = "$mod.pm") =~ s!::!/!g;
        require $mod_pm;

        $list = ${"$mod\::LIST"};
    }

    my $scenario = {
        summary => $list->{summary},
        participants => [],
    };

    $scenario->{description} = "This scenario is generated from ".
        ($mod ? "<pm:$mod>" : "an <pm:Acme::CPANModules> list").".";

    for (qw/datasets/) {
        if ($list->{"bench_$_"}) {
            $scenario->{$_} = $list->{"bench_$_"};
        }
    }

    for my $e (@{ $list->{entries} }) {
        my @per_function_participants;

        # we currently don't handle entries with 'modules'
        next unless $e->{module};

        # per-function participant
        if ($e->{functions}) {
            for my $fname (sort keys %{ $e->{functions} }) {
                my $fspec = $e->{functions}{$fname};
                my $p = {
                    module => $e->{module},
                    function => $fname,
                };
                my $has_bench_code;
                for (qw/code code_template fcall_template/) {
                    if (defined $fspec->{"bench_$_"}) {
                        $p->{$_} = $fspec->{"bench_$_"};
                        $has_bench_code++;
                    }
                }
                next unless $has_bench_code;
                push @per_function_participants, $p;
            }
        }

        my $p = {
            module => $e->{module},
        };
        my $has_bench_code;
        for (qw/code code_template fcall_template/) {
            if ($e->{"bench_$_"}) {
                $has_bench_code++;
                $p->{$_} = $e->{"bench_$_"};
            }
        }
        if ($has_bench_code || (!@per_function_participants && !$scenario->{datasets})) {
            push @{ $scenario->{participants} }, $p;
        }
        push @{ $scenario->{participants} }, @per_function_participants;
    }

    [200, "OK", $scenario];
}

1;
# ABSTRACT:

=head1 SEE ALSO

L<Acme::CPANModules>

L<Bencher>
