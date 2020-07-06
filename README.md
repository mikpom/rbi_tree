# Interval Tree for Python #

This is a Cython-wrapped red-black interval tree from
[IvanPinezhaninov/IntervalTree/](https://github.com/IvanPinezhaninov/IntervalTree).

To install:

    pip3 install rbi-tree

Example usage:

    >>> from rbi_tree.tree import Tree
    >>> t = Tree()
    >>> t.insert(60, 80, value=10) # start stop and value are ints
    >>> t.insert(20, 40, value=20)
    >>> t.find(10, 30)
    [20]
    >>> t.find(40, 50) # half open so it should give nothing
    []
    >>> t.remove(20, 40, value=20) # start,stop,value tuple identifies
    ...                            # the interval
    >>> t.find(10, 30) # now it finds nothing
    []
    >>> t.find_at(70) # search at point
    [10]

