#`ni` by Example, Chapter 2 (pre-alpha release)

Welcome to the second part of the tutorial. At this point, you should be familiar with fundamental row and column operations; sorting; basic Perl operations; file I/O and comopression; and some basic principles of `ni` style. Before continuing, it's advisable to read over the first part of the horribly misnamed [cheatsheet](cheatsheet.md) to see some of the operations that were glossed over.

The key concept that we will cover (and really, the key to `ni`'s power) is the ability of `ni` to package itself and execute in-memory on remote machines. To that end, we will explain the use of `ni` on local Docker instances; over `ssh` on remote machines, and how to use `ni` to write simple and powerful Hadoop Streaming jobs. 

Other key concepts for this tutorial include streaming reduce operations, data closures, and cell operations. We'll also cover more `ni`-specific Perl extensions, and some important parts of Perl that will be particularly useful in `ni`.

Before we get into anything too useful, however, we need to take a detour into how `ni` works at a high level. It's not completely necessary to know this in order to use `ni`, but understanding this will help you think like `ni`. 

##`ni` is self-modifying

`ni` is written in [self-modifying Perl](https://github.com/spencertipping/writing-self-modifying-perl), and the ability to rewrite its source code is the key to its virality. In biological terms, it is useful to think of `ni` is truly viral; it can be run in-memory on any machine with bash and Perl.


####`ni` evaluation basics
Part of the reason `ni` spells are easy to build is because they are pipelined by default, and in particular, they are pipelined with Unix pipes; the output of one `ni` operation is piped as input to the next operation.

```
ni <op1> <op2> <op3> ... <opN>
``` 
is, for the most part, equivalent to 

```
ni <op1> | ni <op2> | ni <op3> | ... | ni <opN>
```

`ni --explain` works by telling you what each `<op>` above is.

However, this isn't quite the whole story. 

####`::closure_name[...]`: Create a data closure

`$ ni ::five[n5] n3p'r a, five'`

```
1       12345
2       12345
3       12345
(END)
```
Any `ni` operations executable on the machine from whose context `ni` is being executed can be turned into a data closure. This caveat will become more important when we start using `ni` to execute on machines other than the ones we develop on.  The closure can be referenced within a Perl snippet as  `p'... closure_name ...'`

```
$ ni --explain ::five[n5] n3p'r a, five'
["memory_data_closure","five",[["n",1,6]]]
["n",1,4]
["perl_mapper","r a, five"]
```


Data closures provide a counterexample to the basics of `ni` evaluation written above. 

`$ ni ::five[n5] | ni n3p'r a, five'`

```
1       five
2       five
3       five
(END)
```

The reason that the example including pipes gives different results than the example with no pipes is that **creating the data closure modifies `ni` itself**.  In the piped example, the first `ni` is modified but is not used; the second `ni` is identical to the first `ni` before the data closure was called into existence, so it cannot access the data closure built in the first `ni`.

####Perl Bareword Interpretation
The piped example above bears a second look for the reason that it returns output rather than raising an error, even though the data closure `five` is not in its namespace.

`$ ni ::five[n5] | ni n3p'r a, five'`

```
1       five
2       five
3       five
(END)
```

The Perl interpreter will convert missing barewords (i.e. things that do not start with a Perl sigil [`$, @, %`, etc.]) as a string. This trick is useful for writing strings without spaces within Perl environments; most of them do not need to be quoted. It is good `ni` style to avoid using quotes when they are unnecessary.

We now return to our regularly-scheduled programming.

####Data Closure Evaluation and `ni` self-modification
Data closures, regardless of where they are written in a ni spell, will be evaluated before everything else, and in the order that they are written.

That means that `$ ni ::five[n5] n3p'r a, five'` ie equivalent to `$ ni n3p'r a, five' ::five[n5]`, even though in the latter, it looks like it's referencing something that was computed later in the pipeline.

Data closures are (or will be shortly implemented such that they are) computed in order; that means you can use one data closure to compute another, so long as the one computed from is expressed in the stream before the one which uses it to do some computation.

We can rewrite a `ni` pipeline a little more accuartely as the following:

```
$ ni ::dataclosure1 ... ::dataclosureM <op1> <op2> ... <opN> 
```

```
$ ni ::dataclosure1 ... ::dataclosureM (export to) ni_prime
$ ni_prime op1 | ni_prime op2 | ... | ni_prime opN
```

We will see how `ni` actually does this in the following sections.


##`ni` is a quine

A _quine_ (pronounced: KWINE) is a program that prints its source code when it is run. If you haven't run into quines before (or the equivalent terms selfrep or self-representing program), and you go out and start looking at them, they can be mind-bending and near-impossible to read. That is the correct reaction; you should start becoming comfortable with that feeling.

We'll write a classic quine in Scheme (or Lisp), then a quine in Perl, and then demonstrate that `ni` is a quine without getting too deep into the details.

####Scheme/Lisp mini-tutorial
If you're already familiar with Lisp syntax, skip ahead to the next section. If you're not familiar with either of those languages, they're much more worth learning than `ni`, but it's probably more urgent that you learn `ni` for some reason, so this mini-tutorial will teach you enough to understand our first example quine.

Start by checking out [repl.it](http://www.repl.it). Select Scheme and you'll be taken to a Scheme REPL.

Here's what you need to know:

* Function applcation in Scheme/Lisp starts with an open parenthesis.
  * `(+ 1 2)` yields `3`. 
  * `(* 5 6 7)` yields `210`
* Scheme lists are written in parentheses and are delimited by spaces.
* The function `list` returns a list of its arguments:
  * `(list 1 3 5)` yields `(1 3 5)`
* The function `quote` takes one argument and returns its literal value:
  * `(quote 5)` yields `5`
  * `(quote (list 1 2 3))` yields `(list 1 2 3)`--note that the list function was not evaluated.
* `lambda` defines an anonymous function with any number of named parameters.
  * `(lambda (u v) (u + v))` yields a closure. There's a lot of ink spilled on what a closure is and does. For the purpose of this tutorial, you can think of a closure as a a function that has not been supplied its arguments.
  * `((lambda (u v) (u + v)) 4 5)` yields 9, because the 4 and the 5 are passed as arguments to the lambda.

####A simple quine in Scheme
Let's build a quine, starting with this piece:

```
(lambda (x)
   (list x (list (quote quote) x))
```

`lambda` creates an anonymous function which, on input x, returns a list with first element `x`. The second element of the list is also a list. The first element of the sublist is the result of  `(quote quote)`, and the second element is `x`. To make the operation of this function more concrete, head over to  and look at what happens when we do the following:

```
((lambda (x)
    (list x (list (quote quote) x)))
  1)
=> (1 (quote 1))
```
So when we apply ths function to an argument, we get back the argument, followed by a list consisting of `quote` and the argument.

Already that should feel like a step in the right direction; we have a function that takes a piece of data, reproduces that data and then a quoted representation of that data. In quines with this structure, this function is often referred to as "the code."

What we need now is the appropriate piece of data to feed to the code. We know our data has to reproduce our code, so that means what we feed to our code must be a string representation of itself. We do this by applying `quote` to the text of the code.

```
((lambda (x)
  (list x (list (quote quote) x)))
 (quote
  (lambda (x)
   (list x (list (quote quote) x)))))
   
=> ((lambda (x) (list x (list (quote quote) x))) (quote (lambda (x) (list x (list (quote quote) x)))))
```

Note that not all quines are structured this way (with code and data to interpret the code), but these are the simplest types of quines to write and explain.

For those inclined to theoretical computer science, [David Madore's tutorial on quines](http://www.madore.org/~david/computers/quine.html) is excellent.  For more examples quines, see [Gary P. Thompson's page](http://www.nyx.net/~gthompso/quine.htm)

####A quine in Perl

```
#!/usr/bin/perl
eval($_=<<'_');
print "#!/usr/bin/perl\neval(\$_=<<'_');\n${_}_\n"
_
```

This code uses heredoc syntax, which is a way of writing multi-line strings in bash, POSIX, and Perl (and other Perl-influenced languages like PHP and Ruby). Enrichment on heredocs is available[... here](http://www.tldp.org/LDP/abs/html/here-docs.html).

Heredocs start with `<<` followed by a delimiter which is the instruction to the interpreter of where the string stops. In this case, the delimiter is the character `_`. Surrounding the delimiter with single quotes, as above, allows for string interpolation within heredocs; without these quotes around the delimiter, no string interpolation is allowed.

Heredocs can be parsed in non-obvious ways, and the non-obvious parsing is used in this quine. The heredoc can be parsed starting on the line after the `<<` and the delimiter, and that is what is used here. Due to the parsing, the string `print "#!/usr/bin/perl\neval(\$_=<<'_');\n${_}_\n"` is stored into `$_`.


If you found the previous paragraphs on heredocs inscrutable, don't worry too much because it's not so important; like the quine we saw in the previous section, this quine is composed of code:

```
#!/usr/bin/perl
eval($_=<<'_');
print 
```
and data:

```
"#!/usr/bin/perl\neval(\$_=<<'_');\n${_}_\n"
_
```

What makes this quine a bit more difficult to read is that there is some overlap between the code and the data involving the assignment statement. Also, Perl.


Copying the lines and running: 

```
$ pbpaste > quine.pl
$ cat quine.pl | perl
#!/usr/bin/perl
eval($_=<<'_');
print "#!/usr/bin/perl\neval(\$_=<<'_');\n${_}_\n"
_
```

Most of the trickery is done using the heredoc syntax (which is a way of writing multi-line strings starting with ). Heredocs are parsed in a non-obvious way. In this case, at a high level, the code works like this:

1. `$_` becomes the code written as a heredoc, which is just the 3rd line. The heredoc parser knows to skip the end of the line.
2. `eval $_` happens, causing that code to be executed
3. inside `eval $_`, `print "#!... ${_}..."` happens -- notice the reference back to `$_`, which contains the code being evaled

The key here is that because the code is inside a single-quoted heredoc, it can be interpolated directly into its own representation.

####Quines, so what?

When studying quines, most of the examples you see don't do anything (other than print themselves), which should make us ask why they're even worth studying.

Consider what happens when we pipe the output of a quine back to an interpreter. Copying our quine from above

```
$  cat quine.pl | perl | perl | perl
#!/usr/bin/perl
eval($_=<<'_');
print "#!/usr/bin/perl\neval(\$_=<<'_');\n${_}_\n"
_
```

We can keep connecting output pipes to input pipes and getting the same output. If we think about pipes more generally, we might imagine taking a quine, passing its output as text over ssh, and executing that quine using perl on another machine. A quine can be passed from machine to machine, always with the same output; it is a fixed point of the code under the evaluation/interpretation operator.



####`//ni`: Print `ni`'s _current_ source
As a reminder, you should be using a vanilla (to the greatest extent possible) bash shell for these commands. If you're not running a bash shell, `bash` at the terminal will pop you into a bash shell.


`ni` is a quine. To get `ni` to print its source, run:

`$ ni //ni`

```
#!/usr/bin/env perl
$ni::self{license} = <<'_';
ni: https://github.com/spencertipping/ni
Copyright (c) 2016 Spencer Tipping | MIT license
....
_
....
```

Like the example Perl quine above, `ni` uses the tricky interpretation of the heredoc syntax, and the semicolon at the end of the line is not subsumed into the multi-line string. Also, because `ni` is self-modifying, `//ni` cannot be said to print `ni`'s source per se; instead it prints `ni`'s source at the time that it is called.

This provides us with a surprising power. We can now execute `ni` indirectly by piping `ni`'s source to `perl -`. The `-` instructs perl to read code from the command line.  More generally,

> `$ ni ...` is equivalent to `ni //ni | perl - ...`

If we think about a pipe more generally, as passing data not just from one process to another, but from one machine to another, you should envision the possibilities of offloading work from one machine to another that's better equipped to solve your target problem.


##`ni` is a self-modifying quine

In the section on `ni` being self-modifying, it was mentioned that `ni` execution follows a structure something like this:

```
$ ni ::dataclosure1 ... ::dataclosureM <op1> <op2> ... <opN> 
```

is equivalent to

```
$ ni ::dataclosure1 ... ::dataclosureM (export to) ni_prime
$ ni_prime op1 | ni_prime op2 | ... | ni_prime opN
```

In fact, this `ni_prime` is a local modification of `ni`, which incorporates data closures. The details are outside the scope of how this occurs are outside the scope of this tutorial, but here's some evidence that this is going on.

```
$ ni //ni | wc -c
  743514
```

```
$ ni ::my_closure[n10] //ni | wc -c
  743569
```

If we've really inserted a data closure into `ni` as a quine, `ni` is really a quine, then we should be able to execute it, for example, by passing the code to perl.

```
$ ni ::ten[n10] //ni | perl - n1p'ten'
```

```
1
2
3
4
5
6
7
8
9
10
(END)
```

This is really quite magical; we've taken `ni`, made a simple but powerful modification to its source, then passed the entire source to `perl` (which had no idea what it would receive), and it was able to access something that doesn't exist in the installed version of `ni`:

```
$ ni //ni | perl - n1p'ten'
```

```
ten
(END)
```


##SSH, Containers, and Horizontal Scaling

We've covered why `ni` can be indirectly executed on the same machine using the identity `$ ni ...` == `$ ni //ni | perl - ...`. The natural next steps are to explore indirect execution of `ni` scripts on virtual machines; on machines you control via `ssh`; and on multiple cores in the same machien.

####`C`: execute in a container

Running in containers requires that Docker be installed on your machine. It is easy to install from [here](https://www.docker.com/).

Running containers can be especially useful to take advantage of better OS-dependent utilities. For example, Mac OS X's `sort` is painfully slow compared to Ubuntu's. If you are developing on a Mac, there will be a noticeable performance change using `$ ni n1E7 g` vs `$ ni n1E7 Cubuntu[g]`.

 Containers are also useful for testing the portability of your code.


####`s`: execute over `ssh`

You will need to set up your hosts properly in your `.ssh/config` to use a named host. For example, if you log in with the command `ssh user.name@host.name:port.number`, you would create an alias for that host by entering the following lines in your `.ssh/config` 

```
host <alias>
    HostName <host.name>
    Port <port.number>
    User <user.name>
```

You would access this as `$ ni ... s<alias>[...]`

You will want to do this to reduce keystrokes; remember that within the brackets , you will have access to the filesystem of the 

####`S`: Horizontal Scaling 
`$ ni <data> S<# cores>[...]`: distributes the computation of `...` across `<# cores>` processors. However, running an operator with `S8` on a machine with only two cores is not going to give 8x the computing power. In fact, if you request more cores than you have, you'll likely end up slowing your progress.

  
##HDFS I/O & Hadoop Streaming
####How `ni` Interacts with Hadoop Streaming
When `ni HS...` is called, `ni` packages itself as a `.jar` to the configured Hadoop server, which includes all the instructions for Hadoop to run `ni`.

When `ni` uploads itself, it will also upload all data that is stored in data closures; if these closures are too large, the Hadoop server will refuse the job.

####Hadoop I/O
* `hdfs://<path>`: HDFS `cat`
  * Equivalent to `hadoop fs -cat <path>`
* `hdfst://<path>`: HDFS `text`
  * Equivalent to `hadoop fs -text <path>`


####Hadoop Streaming
* `HS[mapper] [combiner] [reducer]`: Hadoop Streaming Job
  * Any `ni` snippet can be used for the mapper, combiner, and reducer. Be careful that all of the data you reference is available to the Hadoop cluster; `w/W` operations referencing a local file are good examples of operations that may work on your machine that may fail on a Hadoop cluster with no access to those files.
  * `_` -- skip the mapper/reducer/combiner. 
  * `:` -- apply the trivial operation (i.e. redirect STDIN to STDOUT) for the mapper/reducer/combiner
  * If the reducer step is skipped with `_`, the output may not be sorted, as one might expect from a Hadoop operation. Use `:` for the reducer to ensure that output is sorted correctly.
  * Remember that you will be limited in the size of the `.jar` that can be uploaded to your Hadoop job server; you can upload data closures that are large, but not too large.
* Using HDFS paths in Hadoop Streaming Jobs:
  * `ni ... \'hdfst://<path> HS...`
  * The path must be quoted so that `ni` knows to get the data during the Hadoop job, and not collect the data, package it with itself, and then send the packaged data as a `.jar`.

####Hadoop Streaming Word Count in `ni`
The classic MapReduce job is counting words; in `ni`, the script is concise and rather beautiful.

`ni //ni HS[FWpF_ ]_c`

When we introduce streaming reduce in the next chapter, we can make this process even more efficient by reducing the amount of text sent from mappers to reducers.

##Conclusion

Congrats on making it through another section.