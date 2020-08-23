use Test;
plan 3;

use Shell::Piping;

{ #1
    my @a;
    px<sleep 3>:timeout(1) |» @a;

    my $exception-ok;
    CATCH {
        when X::Proc::Async::Timeout { $exception-ok = ? .command.ends-with('sleep') }
    }
    LEAVE ok $exception-ok, ‚sleep timed out‘;
}
{ #2
    my @a;
    px<sleep 3> |» (px<sort>:timeout(1)) |» @a;

    my $exception-ok;
    CATCH {
        when X::Proc::Async::Timeout { $exception-ok = ? .command.ends-with('sort') }
    }
    LEAVE ok $exception-ok, ‚timeout in middle position‘
}
{ #3
    my @a = 1,2,3;
    @a |» (px<sleep 3>:timeout(1)) |» @a;

    my $exception-ok;
    CATCH {
        when X::Proc::Async::Timeout { $exception-ok = ? .command.ends-with('sleep') }
    }
    LEAVE ok $exception-ok, ‚timeout in last position‘;
}
