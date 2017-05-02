Lazy evaluation, also known as "call by need", is an evaluation strategy where
values are produced only when needed. Lazy evaluation is the opposite of eager
evaluation, Python's normal evaluation model, where functions are executed as
seen and values are produced immediately.

In this talk we will define lazy evaluation and contrast it with eager
evaluation. We will discuss tools that exist in Python for using lazy evaluation
and show how we can build on the primitives to better represent computations. We
will introduce common vocabulary for discussing evaluation models, and compare
different systems for implementing lazy evaluation. Finally, we will discuss
optimizations that can be made to optimize lazily evaluated expressions.
