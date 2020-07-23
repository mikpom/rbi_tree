from unittest import TestCase
import unittest
import io
import pickle
from rbi_tree.tree import ITree


class TestTreeCase(TestCase):
    def test_tree(self):
        t = ITree()
        i1 = t.insert(60,80)
        i2 = t.insert(20,40)

        # Test find
        ivs = t.find(10,30)
        self.assertEqual(len(ivs), 1)
        self.assertEqual(ivs[0], i2)
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

        t.remove(ivl[0])
        ivs = t.find(50,70)
        self.assertEqual(len(ivs),0)

    def test_iterate(self):
        t = ITree()
        for pos in reversed(range(10)):
            num = t.insert(pos, pos+1)

        starts,ends,ids = list(zip(*t.iter_ivl()))
        self.assertEqual(starts, tuple(range(10)))
        self.assertEqual(ends, tuple([i+1 for i in range(10)]))

    def test_copy(self):
        t = ITree()
        for pos in range(10):
            num = t.insert(pos, pos+1)

        t2 = t.copy()
        starts,ends,ids = list(zip(*t2.iter_ivl()))
        self.assertEqual(starts, tuple(range(10)))
        self.assertEqual(ends, tuple([i+1 for i in range(10)]))

        s = io.BytesIO()
        pickle.dump(t, s)
        s.seek(0)
        t3 = pickle.load(s)
        self.assertEqual(len(list(t3.iter_ivl())), 10)
        
if __name__=='__main__':
    unittest.main()

