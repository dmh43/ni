#Exercises

##Overiew
Learning a programming language, like any language, is difficult without the opportunity for structured practice.

##Stream Operators

Write three `ni` snippets to compute the first 100 triangular numbers (1,3,6,10,15...)

1. Use a ni stream operator to generate a range, then use a perl snippet and the formula `T_n = n*(n+1)/2`
2. Use a ni stream operator to generate a range, then use a perl snippet to generate two columns of data; then write another perl snippet that combines the two columns appropriately to generate the ouput numbers.
3. Write a different solution from #1 and #2

##Edge Cases

1. Consider this `ni` snippet: `ni ::foo[n5] n1p'r split /\n/, foo'`
   - Why is `n1` necessary before `p'r split...`?


##Concision

Make the following `ni` statements more concise.

1. `ni n10m'r ru {|l| Math.log(l.a` **i** `) > 2}' `


##Fluency

Explain what the following `ni` snippets do:

1. `ni n100p'sum rw {1}'`