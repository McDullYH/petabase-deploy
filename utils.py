#!/usr/bin/python
# -*- coding:utf-8 -*-
import sys


if __name__=="__main__":
    if sys.argv[1]=="count_intersection":
        a=set(sys.argv[2].split(','))
        b=set(sys.argv[3].split(','))
        intersection= set(a) & set(b) 
        sys.exit(len(intersection))
    elif sys.argv[1]=="test_subset":
        big=set(sys.argv[2].split(','))
        small=set(sys.argv[3].split(','))
        sys.exit(big >= small)

