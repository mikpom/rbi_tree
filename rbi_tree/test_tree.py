from unittest import TestCase
import unittest
from rbi_tree.tree import Tree

class TestTreeCase(TestCase):
    def test_tree(self):
        t = Tree()
        t.insert(60,80,value=10)
        t.insert(20,40,value=20)

        ivs = t.find(10,30)
        self.assertEqual(len(ivs),1)
        self.assertEqual(ivs[0],20)

        ivs = t.find(40,41)
        self.assertEqual(len(ivs),0)

        ivs = t.find(19,20)
        self.assertEqual(len(ivs),1)

        ivs = t.find_at(20)
        self.assertEqual(len(ivs),1)

        # Test insert duplicate
        with self.assertRaises(ValueError):
            t.insert(20,40,value=20)
        
        t.insert(20,40,value=30)
        ivs = t.find(10,30)
        self.assertEqual(len(ivs),2)

        # Test remove nonexistent
        with self.assertRaises(ValueError):
            t.remove(60, 80, 20)

        t.remove(60, 80, 10)
        ivs = t.find(50,70)
        self.assertEqual(len(ivs),0)
        
if __name__=='__main__':
    unittest.main()

