import os
import sys
import copy
from unittest import TestCase
import unittest
import io
import pickle
import rbi_tree.tree
from rbi_tree.tree import ITree, ITreed
import gc

class CustomClass(object):
    def __init__(self, a, b):
        self.a = a
        self.b = b

class TestTreeCase(TestCase):
    def test_simple(self):
        for value in ['abc', 100, {0:1}, list('abc')]:
             t = ITree()
             i1 = t.insert(60, 80)
             i2 = t.insert(20, 40, value=value)

             ivs = t.find(10, 30)
             self.assertEqual(len(ivs), 1)
             iv = ivs[0]
             self.assertEqual(iv[2], value)

    def test_iterate(self):
        t = ITree()
        for pos in reversed(range(10)):
            num = t.insert(pos, pos+1)

        starts, ends, ids = list(zip(*t.iter_ivl()))
        self.assertEqual(starts, tuple(range(10)))
        self.assertEqual(ends, tuple([i+1 for i in range(10)]))


    def test_leak(self):
        trees = []
        for tren in range(10):
            t = ITree()
            for pos in range(100):
                t.insert(pos, pos+1, CustomClass(tren+1, pos))
            trees.append(t)
            gc.collect()
        for t in trees:
            for s,e,v in t.iter_ivl():
                self.assertGreater(v.a, 0)
                

    def test_pickling(self):
        # Test for bug in https://github.com/mikpom/rbi_tree/issues/4
        t = ITree()
        for pos in range(100):
            num = t.insert(pos, pos+1)

        s = io.BytesIO()
        pickle.dump(t, s)

        for i in range(100):
            t3 = pickle.loads(s.getvalue())
            del t3
            gc.collect()

        t3 = pickle.loads(s.getvalue())
        self.assertEqual(len(list(t3.iter_ivl())), 100)
        
    def test_copy(self):
        t = ITree()
        for pos in range(10):
            num = t.insert(pos, pos+1)

        t2 = copy.copy(t)
        starts,ends,ids = list(zip(*t2.iter_ivl()))
        self.assertEqual(starts, tuple(range(10)))
        self.assertEqual(ends, tuple([i+1 for i in range(10)]))

    def test_find_at(self):
        t = ITree()
        for i, int in enumerate([(1,3),(5,9),(6,10)]):
            t.insert(*int, i)
        res = t.find_at(2)
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0], (1,3,0))

class TestTreedCase(TestCase):
    def test_copy(self):
        t = ITreed()
        for pos in range(10):
            num = t.insert(pos, pos+1)

        t2 = copy.copy(t)
        starts,ends,ids = list(zip(*t2.iter_ivl()))
        self.assertEqual(starts, tuple(range(10)))
        self.assertEqual(ends, tuple([i+1 for i in range(10)]))
    
    def test_tree_with_deletion(self):
        t = ITreed()
        i1 = t.insert(60,80)
        i2 = t.insert(20,40)

        # Test find
        ivs = t.find(10,30)
        self.assertEqual(len(ivs), 1)
        self.assertEqual(ivs[0], (20, 40, i2))
        self.assertEqual(t.get_ivl(i2), [20, 40])

        # Test back-to-back non-overlapping
        self.assertEqual(len(t.find(40,41)), 0)
        self.assertEqual(len(t.find(19,20)), 0)
        # But finds at point
        ivs = t.find_at(20)
        self.assertEqual(len(ivs),1)

        # Test remove nonexistent
        with self.assertRaises(ValueError):
            t.remove(1000)

        # Test remove nonexistent
        with self.assertRaises(TypeError):
            t.remove('abc')
            
        # Test remove
        ivl = t.find(60, 80)
        self.assertEqual(len(ivl), 1)

        s,e,sid = ivl[0]
        t.remove(sid)
        ivs = t.find(50,70)
        self.assertEqual(len(ivs),0)

        
if __name__=='__main__':
    unittest.main()

