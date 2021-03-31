# Copyright 2020-2021 Mikhail Pomaznoy
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
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF 

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
        

ctypedef Interval[int, int] CIntervalInt
ctypedef IntervalTree[int, int] CTreeInt
ctypedef map[int, CIntervalInt*] Ivlmap
ctypedef pair[int, CIntervalInt*] keyval

ctypedef Interval[int, PyObject*] CIntervalObj
ctypedef IntervalTree[int, PyObject*] CTreeObj

cdef class ITree:
    cdef CTreeObj* tree

    def __cinit__(self):
        self.tree = new CTreeObj()

    def __dealloc__(self):
        cdef vector[CIntervalObj] intervals = self.tree.intervals()
        cdef vector[CIntervalObj].iterator it = intervals.begin()
        while it != intervals.end():
            Py_DECREF(<object>deref(it).value)
            inc(it)
        del self.tree

    def __reduce__(self):
        intervals = list(self.iter_ivl())
        return (ITree._from_intervals, (intervals,))

    def insert(self, start, end, value=None):
        """Insert an interval [start, end) and returns an id
        of the interval. Ids are incrementing integers, i.e. 0,1,2 etc."""
        
        cdef CIntervalObj* ivl = new CIntervalObj(
            start, end, <PyObject*>value)
        self.tree.insert(deref(ivl))
        Py_INCREF(value)
        return

    def find(self, int start, int end):
        """Search intervals overlapping [start, end). Returns list of 
        overlapping intervals' ids."""
        cdef CIntervalObj* ivl = new CIntervalObj(start,end)
        cdef vector[CIntervalObj] out
        self.tree.findOverlappingIntervals(deref(ivl), out)
        del ivl
        a = []
        cdef vector[CIntervalObj].iterator it = out.begin()
        while it != out.end():
            # Have to exclude for the sake of half-openness
            if deref(it).high!=start and deref(it).low!=end:
                val = <object>deref(it).value
                a.append( (deref(it).low, deref(it).high, val) )
            inc(it)
        return a

    def _from_intervals(cls, intervals=None, tot=0):
        cdef CTreeObj* tree = new CTreeObj()
        tot = 0
        cdef CIntervalObj* ivl
        cdef PyObject* _val
        if not intervals is None:
            for start, end, val in intervals:
                _val = <PyObject*>val
                ivl = new CIntervalObj(start, end, _val)
                tree.insert(deref(ivl))
        return ITree._from_data(tree)
    _from_intervals = classmethod(_from_intervals)

    @staticmethod
    cdef ITree _from_data(CTreeObj* tree):
        cdef ITree itree = ITree.__new__(ITree)
        itree.tree[0] = CTreeObj(deref(tree))
        return itree

    def copy(self):
        """Create a copy of Interval tree."""
        return ITree._from_data(self.tree)
        
    def find_at(self, int point):
        """Search for intervals containing specified point. Returns list of 
        overlapping intervals' ids."""
        cdef vector[CIntervalObj] out
        self.tree.findIntervalsContainPoint(point, out)
        a = []
        cdef vector[CIntervalObj].iterator it = out.begin()
        while it != out.end():
            if not deref(it).high == point:
                val = <object>deref(it).value
                a.append(a.append( (deref(it).low, deref(it).high, val) ))
            inc(it)
        return a

    def iter_ivl(self):
        """Iterate over all intervals. Yields tuples (start, end, id)."""
        cdef vector[CIntervalObj] intervals = self.tree.intervals()
        cdef vector[CIntervalObj].iterator it = intervals.begin()
        while it != intervals.end():
            val = <object>deref(it).value
            yield (deref(it).low, deref(it).high, val)
            inc(it)

cdef class ITreed:
    cdef CTreeInt* tree
    cdef Ivlmap ivldata
    cdef map[int, CIntervalInt*].iterator datapos
    cdef tot

    def __cinit__(self):
        self.tree = new CTreeInt()
        self.ivldata = Ivlmap()
        self.datapos = self.ivldata.begin()
        self.tot = 0

    def __dealloc__(self):
        del self.tree

    def __reduce__(self):
        intervals = list(self.iter_ivl())
        return (ITreed._from_intervals, (intervals, self.tot))

    def _from_intervals(cls, intervals=None, tot=0):
        cdef CTreeInt* tree = new CTreeInt()
        cdef Ivlmap ivldata = Ivlmap()
        tot = 0
        cdef CIntervalInt* ivl
        datapos = ivldata.begin()
        if not intervals is None:
            for start, end, val in intervals:
                ivl = new CIntervalInt(start, end, val)
                tree.insert(deref(ivl))
                datapos = ivldata.insert(datapos,
                                    keyval(ivl.value, ivl))
                tot = tot
        return ITreed._from_data(tree, ivldata, tot)
    _from_intervals = classmethod(_from_intervals)

    @staticmethod
    cdef ITreed _from_data(CTreeInt* tree, Ivlmap& ivldata, int tot):
        cdef ITreed itree = ITreed.__new__(ITreed)
        itree.tree[0] = CTreeInt(deref(tree))
        itree.ivldata = ivldata
        itree.tot = tot
        return itree

    def copy(self):
        """Create a copy of Interval tree."""
        return ITreed._from_data(self.tree, self.ivldata, self.tot)
        
    def insert(self, start, end):
        """Insert an interval [start, end) and returns an id
        of the interval. Ids are incrementing integers, i.e. 0,1,2 etc."""
        cdef int ivl_id = self.tot
        cdef CIntervalInt* ivl = new CIntervalInt(start, end, ivl_id)
        self.tree.insert(deref(ivl))
        self.datapos = self.ivldata.insert(self.datapos,
                            keyval(ivl.value, ivl))
        self.tot += 1
        return ivl_id

    cdef CIntervalInt* _get_interval(self, id):
        cdef map[int, CIntervalInt*].iterator it = self.ivldata.find(id)
        if it != self.ivldata.end():
            return deref(it).second
        else:
            return NULL
        
    def find(self, int start, int end):
        """Search intervals overlapping [start, end). Returns list of 
        overlapping intervals' ids."""
        cdef CIntervalInt* ivl = new CIntervalInt(start,end)
        cdef vector[CIntervalInt] out
        self.tree.findOverlappingIntervals(deref(ivl), out)
        del ivl
        a = []
        cdef vector[CIntervalInt].iterator it = out.begin()
        while it != out.end():
            # Have to exclude for the sake of half-openness
            if deref(it).high!=start and deref(it).low!=end:
                a.append( (deref(it).low, deref(it).high, deref(it).value) )
            inc(it)
        return a

    def get_ivl(self, id):
        """Return a list [start,end] of the interval with specified id."""
        cdef CIntervalInt* ivl = self._get_interval(id)
        return [deref(ivl).low, deref(ivl).high]

    def find_at(self, int point):
        """Search for intervals containing specified point. Returns list of 
        overlapping intervals' ids."""
        cdef vector[CIntervalInt] out
        self.tree.findIntervalsContainPoint(point, out)
        a = []
        cdef vector[CIntervalInt].iterator it = out.begin()
        while it != out.end():
            if not deref(it).high == point:
                a.append( (deref(it).low, deref(it).high, deref(it).value) )
            inc(it)
        return a

    def remove(self, int id):
        """Delete interval with specified id."""
        cdef CIntervalInt* ivl = self._get_interval(id)
        if not ivl is NULL:
            self.tree.remove(deref(ivl))
        else:
            raise ValueError
        self.ivldata.erase(id)
        del ivl

    def iter_ivl(self):
        """Iterate over all intervals. Yields tuples (start, end, id)."""
        cdef vector[CIntervalInt] intervals = self.tree.intervals()
        cdef vector[CIntervalInt].iterator it = intervals.begin()
        while it != intervals.end():
            yield (deref(it).low, deref(it).high, deref(it).value)
            inc(it)
