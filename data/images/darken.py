#!/usr/bin/python
import os

pairs = [(f, f.replace(".svg", "_dark.svg")) 
         for f in os.listdir(".") if f.endswith(".svg") and "_dark" not in f]

for (l, d) in pairs:
    with open(l, "r") as fl, open(d,"w") as fd:
        fd.write(fl.read().replace("#000000", "#eff1f5"))
    os.system(f"inkscape {d} -o {d.replace('.svg', '.png')}")

