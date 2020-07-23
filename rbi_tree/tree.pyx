# Copyright 2020 Mikhail Pomaznoy
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# distutils: language = c++
from cython.operator cimport dereference as deref, preincrement as inc, address
from libcpp.vector cimport vector
from libcpp.map cimport map
from libcpp.utility cimport pair

cdef extern from "intervaltree.hpp" namespace "Intervals":
    cdef cppclass Interval[T1,T2]:
        Interval(T1 a, T1 b)
        Interval(T1 a, T1 b, T2 val)
        T1 high
        T1 low
        T2 value
    cdef cppclass IntervalTree[T1,T2]:
        IntervalTree()
        IntervalTree[T1,T2] IntervalTree(IntervalTree[T1,T2] other)
        bint insert(Interval&& interval)
        void findOverlappingIntervals(Interval iterval, vector[Interval] out)
        void findIntervalsContainPoint(int point, vector[Interval] out)
        vector[Interval[T1,T2]] intervals()
        bint remove(Interval interval)
        

ctypedef Interval[int, int] CInterval
ctypedef IntervalTree[int, int] CTree
ctypedef map[int, CInterval*] Ivlmap
ctypedef pair[int, CInterval*] keyval

cdef class ITree:
    cdef CTree* tree
    cdef Ivlmap ivldata
    cdef map[int, CInterval*].iterator datapos
    cdef tot

    def __cinit__(self):
        self.tree = new CTree()
        self.ivldata = Ivlmap()
        self.datapos = self.ivldata.begin()
        self.tot = 0

    def __dealloc__(self):
        del self.tree

    def __reduce__(self):
        intervals = list(self.iter_ivl())
        return (ITree._from_intervals, (intervals, self.tot))

    def _from_intervals(cls, intervals=None, tot=0):
        cdef CTree* tree = new CTree()
        cdef Ivlmap ivldata = Ivlmap()
        tot = 0
        cdef CInterval* ivl
        datapos = ivldata.begin()
        if not intervals is None:
            for start, end, val in intervals:
                ivl = new CInterval(start, end, val)
                tree.insert(deref(ivl))
                datapos = ivldata.insert(datapos,
                                    keyval(ivl.value, ivl))
                tot = tot
        return ITree._from_data(tree, ivldata, tot)
    _from_intervals = classmethod(_from_intervals)

    @staticmethod
    cdef ITree _from_data(CTree* tree, Ivlmap& ivldata, int tot):
        cdef ITree itree = ITree.__new__(ITree)
        itree.tree[0] = CTree(deref(tree))
        itree.ivldata = ivldata
        itree.tot = tot
        return itree

    def copy(self):
        """Create a copy of Interval tree."""
        return ITree._from_data(self.tree, self.ivldata, self.tot)
        
    def insert(self, start, end):
        """Insert an interval [start, end) and returns an id
        of the interval. Ids are incrementing integers, i.e. 0,1,2 etc."""
        cdef int ivl_id = self.tot
        cdef CInterval* ivl = new CInterval(start, end, ivl_id)
        self.tree.insert(deref(ivl))
        self.datapos = self.ivldata.insert(self.datapos,
                            keyval(ivl.value, ivl))
        self.tot += 1
        return ivl_id

    cdef CInterval* _get_interval(self, id):
        cdef map[int, CInterval*].iterator it = self.ivldata.find(id)
        if it != self.ivldata.end():
            return deref(it).second
        else:
            return NULL
        
    def find(self, int start, int end):
        """Search intervals overlapping [start, end). Returns list of 
        overlapping intervals' ids."""
        cdef CInterval* ivl = new CInterval(start,end)
        cdef vector[CInterval] out
        self.tree.findOverlappingIntervals(deref(ivl), out)
        del ivl
        a = []
        cdef vector[CInterval].iterator it = out.begin()
        while it != out.end():
            # Have to exclude for the sake of half-openness
            if deref(it).high!=start and deref(it).low!=end:
                a.append(deref(it).value)
            inc(it)
        return a

    def get_ivl(self, id):
        """Return a list [start,end] of the interval with specified id."""
        cdef CInterval* ivl = self._get_interval(id)
        return [deref(ivl).low, deref(ivl).high]

    def find_at(self, int point):
        """Search for intervals containing specified point. Returns list of 
        overlapping intervals' ids."""
        cdef vector[CInterval] out
        self.tree.findIntervalsContainPoint(point, out)
        a = []
        cdef vector[CInterval].iterator it = out.begin()
        while it != out.end():
            if not deref(it).high == point:
                a.append(deref(it).value)
            inc(it)
        return a

    def remove(self, int id):
        """Delete interval with specified id."""
        cdef CInterval* ivl = self._get_interval(id)
        if not ivl is NULL:
            self.tree.remove(deref(ivl))
        else:
            raise ValueError
        self.ivldata.erase(id)
        del ivl

    def iter_ivl(self):
        """Iterate over all intervals. Yields tuples (start, end, id)."""
        cdef vector[CInterval] intervals = self.tree.intervals()
        cdef vector[CInterval].iterator it = intervals.begin()
        while it != intervals.end():
            yield (deref(it).low, deref(it).high, deref(it).value)
            inc(it)
