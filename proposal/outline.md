# Introduction

 (3 minutes; running total: 3 minutes)

I will start by defining eager evaluation. I will introduce this term first
because it is how python already works, so users should quickly understand
it. This will serve to build a shared vocabulary to compare lazy evaluation to
later.

```python
def f(a, b):
    """An arbitrary binary function.
    """
    return a + b

a = f(1, 2)
b = f(a, 3)
```

I will walk through how python evaluates this program. After `a = f(1, 1)` is
evaluated, `a` holds concretely holds the result, `2`. Next, when we call `f(a,
2)`, it is exactly like `f(2, 2)`, because `a` has already been computed.

# Why is Eager the Default?

(2 minutes; running total: 5 minutes)

One of Python's goals is to be easy to read and understand. The eager evaluation
model makes it clear when computation is happening. This makes the performance
of our program easy to understand and debug.

# Definition of Lazy Evaluation

(3 minutes; running total: 8 minutes)

Lazy evaluation, also called call by need, is an evaluation strategy where
values are produced when only needed. With lazy evaluation, The result of an
expression becomes a `thunk`, also called a `closure`, which is an object which
can produce the value when requested.

Rewriting our simple example to be lazy.

```python
def f(a, b):
    """An arbitrary binary function.
    """
    return a + b


a = lambda: f(1, 2)
b = lambda: f(a(), 3)
```

After evaluating the line `a = lambda: f(1, 1)`, we have not yet called `f`. We
can see this if we add a `print` call inside `f`. Instead, we have an object
which can produce the result of the computation when needed. Then, when we need
to use the value to define `b`, we must actually get the value of `a` by
'entering', or calling, the closure and producing the value.

# Thinking of Computations as Expression Trees

(4 minutes; running total: 12 minutes)

We can think of any name in a program as a tree of computations required to
produce some value. If we think of the code above, we can rethink `b` as:

```
       (b)
        f
       / \
      /   \
    (a)  (lit)
     f     3
    / \
   /   \
(lit) (lit)
  1     2
```

Here we can think of `b` as a function call which requires `a` and some literal
value `3`. `a` itself is a function call which requires two literals.

To compute the expresion `b`, we can evaluate expressions bottom up until we are
left with a single value. The first set here would be to evaluate the leaves of
the `a` function call, which are `1` and `2`. These expressions are not composed
of any other computations, meaning they are in 'normal form', so we move up the
tree. Then we find `f`, so we apply `f` to the arguments `1`, and `2` to get a
value `3`. The graph now looks like:

```
       (b)
        f
       / \
      /   \
    (a)  (lit)
     3     3
```

Now, to produce the value `b`, we can do the same thing. We already have a value
for `a`, and `3` was a literal so it is in normal form. Now we can call `f` and
get the final value of `6` for `b`.

# Extending Expression Trees to Directed Graphs

(4 minutes; running total: 16 minutes)

Sometimes expressions do not fit into trees without duplicating expressions. For
example:

```python
sub = lambda: a + b
value = lambda: sub() + sub()
```

This could work as a tree like:

```
    (value)
       +
      / \
     /   \
    /     \
 (sub)   (sub)
   +       +
  / \     / \
 /   \   /   \
a     b a     b
```

but this means that all of `sub` gets repeated, really, we want a graph like:

```
     (value)
    sub + sub
      \   /
       \ /
        +
       / \
      a   b
```

 One problem with our current evaluation approach is that we will 'enter' `sub`
 twice, which will duplicate the work; however, in the eager form, we only
 computed the result once. In order to fix this, we need to 'share' the results
 and rethink how we represent thunks.

# Cell Model Thunks

(3 minute; running total: 19 minutes)

In order to avoid duplicating work, we need to save the result of the
computation. To do that, we can use a flag mark if a thunk has been evaluated or
not like:

```python
class CellThunk:
    not_evaluated = object()  # sentinel

    def __init__(self, code, *args, **kwargs):
        self.code = code
        self.args = args
        self.kwargs = kwargs
        self.value = False

    def __call__(self):
        if self.value is self.not_evaluated:
            self.value = self.code(
                *(arg() for arg in self.args)
                **{key: value() for key, value in self.kwargs.items()}
            )
            # release our subgraph
            del self.code
            del self.args
            del self.kwargs
        return self.value
```

Now, we can rewrite our expression like:

```python
def identity(a):
    return a

sub = CellThunk(operator.add, CellThunk(identity a), CellThunk(identity, b))
value= CellThunk(operator.add, sub, sub)
```

This will only compute `a + b` once.

# Self Updating Thunks

(3 minutes; running total: 22 minutes)

A more compact representation for thunks is to only have the code and the
closure with a special code entry point for an evaluated thunk. This class looks
something like:

```python
class SelfUpdatingThunk:
    def __init__(self, code, *args, **kwargs):
        def updating_code(*args, **kwargs):
            value = code(*args, **kwargs)

            self.code = self.computed_code
            self.args = (lambda: value,)
            self.kwargs = {}

            return value

        self.code = updating_code
        self.args = args
        self.kwargs = kwargs

    @staticmethod
    def computed_code(value):
        return value

    def __call__(self):
        return self.code(
            *(arg() for arg in self.args),
            **{key: value() for key, value in self.kwargs.items()}
        )
```

This style of thunk works by replacing the code cell with code that will update
the thunk itself with code that returns the computed value. This removes the
need for the boolean, the branch, and gives us uniform access to thunks that are
computed or not computed. Another optimization that can be used here is that we
can eschew the `update` code if we know that only ever need the value once.

# More Advanced Sharing With Memoization

(3 minutes; running total: 25 minutes)

What if instead of `sub + sub`, we had literally written out `(a + b) + (a +
b)`, how would lazy evaluation help reduce this? One technique is to memoize the
construction of each `thunk`. This means that for any function and a set of
arguments, we will only ever return a single `thunk` object. In python, we could
do this by hashing the function, arguments, and a frozenset of the keyword only
arguments like:

```python
class MemoizedSelfUpdatingThunk(SelfUpdatingThunk):
    _instance_cache = {}

    def __new__(cls, code, *args, **kwargs):
        key = code, args, frozenset(kwargs.items())
        try:
            thunk = cls._instance_cache[key]
        except KeyError:
            thunk = self._instance_cache[key] = super().__new__(cls)
            super().__init__(thunk, code, *args, **kwargs)

        return thunk

    def __init__(self, *args, **kwargs):
        pass
```

Now, if we write:

```python
sub_1 = MemoizedSelfUpdatingThunk(operator.add, a, b)
sub_2 = MemoizedSelfUpdatingThunk(operator.add, a, b)
```

then `sub_1` is `sub_2`, so we will still only evaluate `a + b` once.

# Questions

(5 minutes; running total: 30 minutes)

Time for questions.
