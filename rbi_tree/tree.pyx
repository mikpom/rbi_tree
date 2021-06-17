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
        void clear()
        IntervalTree[T1,T2] IntervalTree(IntervalTree[T1,T2] other)
        bint insert(Interval&& interval)
        void findOverlappingIntervals(Interval iterval, vector[Interval] out)
        void findIntervalsContainPoint(int point, vector[Interval] out)
        vector[Interval[T1,T2]] intervals()
        IntervalTree[T1,T2] IntervalTree(vector[Interval[T1,T2]] ivls)
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
            val  = <object>(deref(it).value)
            if not val is None:
                Py_DECREF(val)
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
        val = <object>value
        if not val is None:
            Py_INCREF(val)
        del ivl
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

    def _from_intervals(cls, intervals=None):
        tree = cls()
        if not intervals is None:
            for start, end, val in intervals:
                tree.insert(start, end, val)
        return tree
    _from_intervals = classmethod(_from_intervals)

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
                a.append( (deref(it).low, deref(it).high, val) )
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

cdef class ITreed():
    cdef CTreeInt* tree
    cdef Ivlmap ivldata
    cdef map[int, CIntervalInt*].iterator datapos
    cdef tot

    def __cinit__(self):
        self.tree = new CTreeInt()
        self.ivldata = Ivlmap()
        self.datapos = self.ivldata.begin()
        self.tot = 0

    def __init__(self, tot=None):
        if not tot is None:
            self.tot = tot

    def __dealloc__(self):
        del self.tree

    def __reduce__(self):
        intervals = list(self.iter_ivl())
        return (ITreed._from_intervals, (intervals, self.tot))

    def _from_intervals(cls, intervals=None, tot=0):
        tree = cls(tot)
        if not intervals is None:
            for start, end, val in intervals:
                tree._insert(start, end, val)

        return tree
    _from_intervals = classmethod(_from_intervals)


    def _insert(self, start, end, value):
        cdef CIntervalInt* ivl = new CIntervalInt(start, end, value)
        self.tree.insert(deref(ivl))
        self.datapos = self.ivldata.insert(self.datapos,
                            keyval(ivl.value, ivl))
        
    def insert(self, start, end):
        """Insert an interval [start, end) and returns an id
        of the interval. Ids are incrementing integers, i.e. 0,1,2 etc."""
        cdef int ivl_id = self.tot
        self._insert(start, end, ivl_id)
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
