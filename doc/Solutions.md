#Solutions

##Stream and Perl Operators

1. `ni n100p'r a, a*(a+1)/2'`
2. `ni n4p'r a, a + 1' p'r a * b/2'`
3. Many solutions are possible, here's one: `ni n10 ,sA`

##Concision

Make the following `ni` statements more concise.

1. `ni n10m'r ru {|l| Math.log(l.a.to_i) > 2}' `

##Edge Cases

1. Consider this `ni` snippet: `ni ::foo[n5] n1p'r split /\n/, foo'`
   - Why is `n1` necessary before `p'r split...`?
   - **Answer:** The first statement creates a closure, which is an empty data stream. According to [the Perl docs at the time of writing](perl.md), the Perl driver won't execute your code at all if the input stream is empty. Thus, you need to feed it a row using `n1` to kickstart it.


##Fluency

Explain what the following `ni` snippets do:

1. `ni nE5rp'$_ % 2 == 0' p'sum rw {1}'`
   - For the numbers 1 up to 10<sup>5</sup>, inclusive, keep the ones that are divisible by two. While true, read ahead (i.e. read the whole list) and output the sum. 
   - More briefly, this snippet sums all the even integers between 1 and 10,000.
   - You can make the program a bit more readable by replacing the weird (to me) Perl `$_` charater with `a`, and using a streaming reduce to show you're doing rollup:
     - `ni nE5rp'a % 2 == 0' p'sr {$_[0] + a} 0'`