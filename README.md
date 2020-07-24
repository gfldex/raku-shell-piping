# Shell::Piping

[![Build Status](https://travis-ci.org/gfldex/raku-shell-piping.svg?branch=master)](https://travis-ci.org/gfldex/raku-shell-piping)

Shell pipes without a shell but Raku.

## SYNOPSIS

```
use Shell::Piping;

my @result;
my $where = ‚/tmp‘;
px«find $where» |» { /a/ ?? $_ !! Nil } |» px<sort -r> |» @result;
.say for @result.head(10);
```

## LICENSE

All files (unless noted otherwise) can be used, modified and redistributed
under the terms of the Artistic License Version 2. Examples (in the
documentation, in tests or distributed as separate files) can be considered
public domain.

ⓒ2020 Wenzel P. P. Peppmeyer
