# Interval Tree for Python #

This is a Cython-wrapped red-black interval tree from
[IvanPinezhaninov/IntervalTree/](https://github.com/IvanPinezhaninov/IntervalTree).

To install:

    pip install rbi-tree

Example usage:

```python
>>> from rbi_tree.tree import ITree
>>> t = ITree()
>>> t.insert(60, 80, value={'a':'b'}) # start stop are integers
>>> t.insert(20, 40)
>>> t.find(10, 30)
[(20, 40, None)]
>>> t.find(40, 60) # half open so it gives nothing
[]
>>> t.find(40, 61)
[(60, 80, {'a': 'b'})]
```


Class ``rbi_tree.tree.ITreed`` supports interval deletion. This is done via
values assigned automatically and serving as IDs for intervals.

```python
>>> from rbi_tree.tree import ITreed
>>> t = ITreed()
>>> id1 = t.insert(60, 80) # start stop are integers
>>> id1
0
>>> id2 = t.insert(20, 40)
>>> id2
1
```

``Id``s are incrementing integers starting from zero reflecting number
of insertion events.
    
```python
>>> t.find(10, 30)
[(20, 40, 0)]
```
    
Ids of intervals can be used to remove them:

```python
>>> t.remove(1)
>>> t.find(10, 30) # now it finds nothing
[]
>>> t.find_at(70) # search at point
[(60, 80, 0)]
>>> list(t.iter_ivl())
[(60, 80, 0)]
```

