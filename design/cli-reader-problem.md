# CLI reader problem
ni parses canard written as command-line arguments, which is not strictly
possible given that the shell erases most quotation marks. This means that the
reader won't be able to tell the difference between `-m '-ai'` (map over
Ruby/spreadsheet code that negates the first value) and `-m -ai` (use the `-ai`
command on current CLI stack, then let `-m` pick up the rest).

As a result, and by virtue of the read-first-execute-second model, we need to
make data type decisions up front and live with them later. The problem becomes
obvious in cases involving brackets:

```sh
$ ni [-m 'foo[0]']
$ ni [-m 'foo[0] + "]"']
```

In order for ni to correctly parse the second one, it needs to know how Ruby
delimits strings so it doesn't interpret the "]" as a canard list closer.
Obviously this will never work, which leads to an invariant: _all
arbitrary-string arguments must be shell-separated from canard-operative
brackets_. We'd need to write the above examples this way:

```sh
$ ni [-m 'foo[0]' ]                     # whitespace before ] is required
$ ni [-m 'foo[0] + "]"' ]
```

We have a similar problem with certain types of code arguments. For example,
suppose we're doing something like this (return an array of the negated
first-column value):

```sh
$ ni -m [-ai]
```

ni could interpret this as `-m` followed by a canard list of `-ai`, which isn't
correct for this use case.

## First solution: parse-time coercion and closer inference
There aren't any obviously great answers. We'll have this type of problem in
some form as long as shell quotes are erased. There may be a few things we can
do to mitigate the problem in some cases, however:

1. Have custom-parsed symbols that coerce their arguments. This would force
   `-m [-ai]` to parse with `[-ai]` as a string, though you'd be unable to
   write additional closing brackets. (Actually that isn't entirely true; see
   below.)
2. In addition to (1), we can infer the number of closing brackets by
   _attempting to compile alternatives_ and choosing the first one that works.
   So for a case like `[-m [-ai]]`, the second argument `[-ai]]` would need to
   lose one closer to compile properly; then we know we're closing an outer
   list.

This all means we have a new requirement, namely that we know which language
code is written for and that we've done the requisite setup for that language
(mostly Perl, I think). For example:

```sh
$ perl -c <<EOF
f x
EOF
syntax error at - line 1, at EOF
- had compilation errors.
$ perl -c <<EOF
sub f {}
f x
EOF
- syntax OK
$
```

This, in turn, requires that we execute all `BEGIN {}` blocks, taking any
side-effects that result. Due to [the way Perl is
parsed](http://www.perlmonks.org/?node_id=44722), there's no way around this.

### Approximate solution
Rewrite `BEGIN` into something else, and if we can't find a solution then we
explain to the user that `BEGIN` syntactic metaprogramming isn't supported.
This actually isn't a terrible option; `use` can be assumed to be safe. I think
we're in good shape.

### Interaction with metaprogramming
Obviously we can't get this right; we could easily have a world in which the
code in question is written inside a quoted list and can be compiled only once
certain metaprogramming has happened. We could also have a situation like this:

```sh
$ ni -m -. [stuff]              # canard-evaluate the list [stuff]
```

Though in this case the ambiguity can be resolved by having `-m` string-quote
only when the code is immediately juxtaposed:

```sh
$ ni -m [-ai]                   # separate canard list
$ ni -m[-ai]                    # "[-ai]" is a string
```

That does have a certain elegance about it. If you want to use an operator that
won't exist at parse-time but that requires coercions, we can have predefined
identities that coerce their arguments:

```sh
$ ni --mystery-operator \"pl[-ai]
```

## Update after writing parser combinators and stuff
The insanity of this idea is becoming fully apparent. I'm running into
interesting problems like the fact that regular expressions tolerate literal
closing brackets -- in other words, my optimistic assumption that sane
languages require a balance isn't strictly true.

I'm not totally sure what to do here. Putting whitespace around brackets is
just egregious, yet bracket inference is likely to never really work.
Backtracking is insane and error-prone.