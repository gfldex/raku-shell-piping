use Test;
plan 7;

use Shell::Piping;

{ # 1,2,3
    my $commandnotfound = X::Shell::CommandNotFound.new(:cmd(‚raku‘));
    my $commandnoaccess = X::Shell::CommandNoAccess.new(:cmd(‚raku‘));

    my $msg1 = $commandnotfound.message;
    my $msg2 = $commandnoaccess.message;

    X::Shell::CommandNotFound.refine({.cmd eq ‚raku‘}, {‚Please install raku with `apt install Rakudo`‘});
    
    my $msg3 = $commandnotfound.message;
    my $msg4 = $commandnoaccess.message;

    X::Shell::CommandNotFound.refine(:revert-all);
    my $msg5 = $commandnotfound.message;

    nok $msg1 eq $msg3, ‚.refine changed message dynamically‘;
    ok $msg2 eq $msg4, ‚.refine did not spill into different class‘;

    ok $msg5 eq $msg1, ‚refinements can be removed‘;
}
{
    my $ex1 = X::Shell::CommandNotFound.new(:cmd(‚raku‘));
    my $ex2 = X::Shell::CommandNotFound.new(:cmd(‚find‘));

    my $msg1 = $ex1.message;
    my $msg2 = $ex2.message;

    my &b1 = {.cmd eq ‚raku‘};
    
    X::Shell::CommandNotFound.refine(&b1, {‚raku-message-1‘});
    X::Shell::CommandNotFound.refine((my &b2 = {.cmd eq ‚find‘}), {‚find-message-1‘});

    my $msg3 = $ex1.message;
    my $msg4 = $ex2.message;

    is $msg3, ‚raku-message-1‘, ‚first match succeeded‘;
    is $msg4, ‚find-message-1‘, ‚2nd match succeeded‘;

    X::Shell::CommandNotFound.refine(&b2, :revert);
   
    my $msg5 = $ex1.message;
    my $msg6 = $ex2.message;

    ok $msg3 eq $msg5, ‚2nd match was removed‘;
    nok $msg4 eq $msg6, ‚first match is still there‘;
}
