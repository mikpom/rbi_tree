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
from cython.operator cimport dereference as deref, preincrement as inc
from libcpp.vector cimport vector

cdef extern from "intervaltree.hpp" namespace "Intervals":
    cdef cppclass Interval[T1,T2]:
        Interval(T1 a, T1 b)
        Interval(T1 a, T1 b, T2 val)
        T1 high
        T1 low
        T2 value
    cdef cppclass IntervalTree[T1,T2]:
        intervalTree()
        bint insert(Interval&& interval)
        void findOverlappingIntervals(Interval iterval, vector[Interval] out)
        void findIntervalsContainPoint(int point, vector[Interval] out)
        bint remove(Interval interval)

ctypedef Interval[int, int] CInterval
ctypedef IntervalTree[int, int] CTree
        
cdef class Tree:
    cdef CTree* tree

    def __cinit__(self):
        self.tree = new CTree()

    def __dealloc__(self):
        del self.tree

    def insert(self, start, end, value=0):
        cdef CInterval* iv = new CInterval(start,end,value)
        ok = self.tree.insert(deref(iv))
        if not ok:
            raise ValueError('Duplicate intervals')
        
    def find(self, int start, int stop):
        
        cdef CInterval* iv = new CInterval(start,stop)
        cdef vector[CInterval] out
        self.tree.findOverlappingIntervals(deref(iv), out)
        del iv
        a = []
        cdef vector[CInterval].iterator it = out.begin()
        while it != out.end():
            if not deref(it).high <= start:
                a.append(deref(it).value)
            inc(it)
        return a

    def find_at(self, int point):
        cdef vector[CInterval] out
        self.tree.findIntervalsContainPoint(point, out)
        a = []
        cdef vector[CInterval].iterator it = out.begin()
        while it != out.end():
            if not deref(it).high == point:
                a.append(deref(it).value)
            inc(it)
        return a

    def remove(self, int start, int stop, int value=0):
        cdef CInterval* iv = new CInterval(start,stop,value)
        ok = self.tree.remove(deref(iv))
        if not ok:
            raise ValueError('Not found')
        del iv
        
