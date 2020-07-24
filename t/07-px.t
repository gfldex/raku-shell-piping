use Test;
plan 8;

use Shell::Piping;

my $ORIG-PATH = %*ENV<PATH>;
%*ENV<PATH> = './bin:./t/bin';

my $source = px<./t/bin/source>;

#1
is $source.path, './t/bin/source', ‚px single argument without $PATH lookup‘;

#2
$source = px<source>;
is $source.path, './t/bin/source', ‚px single argument with $PATH lookup‘;

#3
$source = px<source 1 2 3>;
is-deeply $source.args, [<1 2 3>], ‚px command with arguments‘;

#4
throws-like { px<not-there> }, X::Shell::CommandNotFound, ‚px X::Shell::CommandNotFound‘;
#5
throws-like { px<./t/07-px.t> }, X::Shell::CommandNoAccess, ‚px X::Shell::CommandNotFound‘;

#6
my $arg = ‚answer‘;
$source = px«source $arg»;
is $source.args[0], $arg, ‚px with string substitution‘;

#7
$source = px{‚source‘, 41.succ};
ok { $source.cmd eq ‚srouce‘ && $source.args[0] == 42 }, ‚px with code block‘;

#8
%*ENV<PATH> = $ORIG-PATH;
my @a;
px<./t/bin/source> |» px<./t/bin/drain> |» @a;
is-deeply @a[0,1,2], ("", "Lorem", "adipiscing"), ‚px works with |»‘;
