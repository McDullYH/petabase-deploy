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

    elif sys.argv[1]=="get_start_addr":
        ip_l=sys.argv[2].split('.')
        mask_l=sys.argv[3].split('.')
        start_l=[ str (int(ip_l[0]) & int(mask_l[0])),
         str (int(ip_l[1]) & int(mask_l[1])),
         str (int(ip_l[2]) & int(mask_l[2])),
         str (int(ip_l[3]) & int(mask_l[3])),
        ]
        start='.'.join(start_l)
        #print "restrict " + start + " mask " + sys.argv[3] +" nomodify"
        print start

